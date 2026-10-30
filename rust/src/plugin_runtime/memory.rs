//! Heap cap for one script, with a record of whether it was hit.
//!
//! QuickJS' own `set_memory_limit` fails an allocation but gives the script
//! no reliable trace: when the engine cannot even allocate the error object,
//! the script sees `throw null`, which looks like a script's own `throw null`.
//! This allocator enforces the cap itself and sets a flag the host reads, so
//! the `memory` status cannot be faked or missed.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use rquickjs::allocator::{Allocator, RustAllocator};

/// Rust allocator that refuses to grow past `limit` bytes of live QuickJS
/// memory. A refused allocation returns null (QuickJS throws "out of
/// memory") and sets `hit`.
pub struct LimitedAllocator {
    limit: usize,
    used: usize,
    hit: Arc<AtomicBool>,
}

impl LimitedAllocator {
    /// The allocator and the flag it sets when the cap is hit.
    pub fn new(limit: usize) -> (Self, Arc<AtomicBool>) {
        let hit = Arc::new(AtomicBool::new(false));
        (
            Self {
                limit,
                used: 0,
                hit: hit.clone(),
            },
            hit,
        )
    }

    fn refuse(&self) -> *mut u8 {
        self.hit.store(true, Ordering::SeqCst);
        std::ptr::null_mut()
    }
}

// SAFETY: every pointer comes from `RustAllocator` (same alignment and size
// header rules); this wrapper only counts sizes and may refuse a request,
// which the trait allows by returning null.
unsafe impl Allocator for LimitedAllocator {
    fn alloc(&mut self, size: usize) -> *mut u8 {
        if self.used.saturating_add(size) > self.limit {
            return self.refuse();
        }
        let ptr = RustAllocator.alloc(size);
        if !ptr.is_null() {
            // SAFETY: `ptr` was just returned by `RustAllocator`.
            self.used += unsafe { RustAllocator::usable_size(ptr) };
        }
        ptr
    }

    fn calloc(&mut self, count: usize, size: usize) -> *mut u8 {
        let total = count.saturating_mul(size);
        if self.used.saturating_add(total) > self.limit {
            return self.refuse();
        }
        let ptr = RustAllocator.calloc(count, size);
        if !ptr.is_null() {
            // SAFETY: `ptr` was just returned by `RustAllocator`.
            self.used += unsafe { RustAllocator::usable_size(ptr) };
        }
        ptr
    }

    unsafe fn dealloc(&mut self, ptr: *mut u8) {
        self.used = self.used.saturating_sub(RustAllocator::usable_size(ptr));
        RustAllocator.dealloc(ptr);
    }

    unsafe fn realloc(&mut self, ptr: *mut u8, new_size: usize) -> *mut u8 {
        let old = RustAllocator::usable_size(ptr);
        if self.used.saturating_sub(old).saturating_add(new_size) > self.limit {
            return self.refuse();
        }
        let new_ptr = RustAllocator.realloc(ptr, new_size);
        if !new_ptr.is_null() {
            self.used = self.used.saturating_sub(old) + RustAllocator::usable_size(new_ptr);
        }
        new_ptr
    }

    unsafe fn usable_size(ptr: *mut u8) -> usize {
        RustAllocator::usable_size(ptr)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refuses_past_the_limit_and_frees_back() {
        let (mut a, hit) = LimitedAllocator::new(1024);
        let p = a.alloc(600);
        assert!(!p.is_null());
        assert!(a.alloc(600).is_null(), "second block does not fit");
        assert!(hit.load(Ordering::SeqCst));
        hit.store(false, Ordering::SeqCst);
        unsafe {
            assert!(
                a.realloc(p, 2000).is_null(),
                "growth past the limit is refused"
            );
            assert!(hit.load(Ordering::SeqCst));
            let p = a.realloc(p, 100);
            assert!(!p.is_null());
            a.dealloc(p);
        }
        assert_eq!(a.used, 0);
        let q = a.calloc(10, 10);
        assert!(!q.is_null());
        unsafe { a.dealloc(q) };
    }
}
