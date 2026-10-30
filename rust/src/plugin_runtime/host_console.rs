//! Console capture: every `console.*` / `Log.log` line of a call, cut and
//! counted so a chatty script cannot grow the result without bound.

use rquickjs::{Ctx, Function, Object};

use super::host::HostEnv;
use super::limits::{MAX_LOG_LINES, MAX_LOG_LINE_CHARS};

/// The lines of one call. Keeps the first [`MAX_LOG_LINES`] lines; when more
/// were written, [`LogBuffer::lines`] shows the first `MAX_LOG_LINES - 1` and
/// a closing "… N lines dropped" line, so the result never has more than
/// `MAX_LOG_LINES` entries.
#[derive(Default)]
pub struct LogBuffer {
    lines: Vec<String>,
    total: usize,
}

impl LogBuffer {
    /// Adds one line, cut at [`MAX_LOG_LINE_CHARS`] characters.
    pub fn push(&mut self, line: String) {
        self.total += 1;
        if self.lines.len() < MAX_LOG_LINES {
            self.lines.push(cut_chars(line, MAX_LOG_LINE_CHARS));
        }
    }

    /// The lines to return.
    pub fn lines(&self) -> Vec<String> {
        if self.total <= MAX_LOG_LINES {
            return self.lines.clone();
        }
        let kept = MAX_LOG_LINES - 1;
        let mut out: Vec<String> = self.lines[..kept].to_vec();
        out.push(format!("… {} lines dropped", self.total - kept));
        out
    }
}

/// Native `log(line)`: the script-side wrapper joins the arguments.
pub fn register<'js>(
    ctx: &Ctx<'js>,
    natives: &Object<'js>,
    env: &std::rc::Rc<HostEnv>,
) -> rquickjs::Result<()> {
    let env = env.clone();
    natives.set(
        "log",
        Function::new(ctx.clone(), move |line: String| {
            env.collector.push_log(line)
        })?,
    )
}

fn cut_chars(s: String, max: usize) -> String {
    match s.char_indices().nth(max) {
        Some((i, _)) => s[..i].to_owned(),
        None => s,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn long_lines_are_cut_by_characters() {
        let mut b = LogBuffer::default();
        b.push("é".repeat(600));
        assert_eq!(b.lines()[0].chars().count(), MAX_LOG_LINE_CHARS);
    }

    #[test]
    fn exactly_the_limit_keeps_every_line() {
        let mut b = LogBuffer::default();
        for n in 0..MAX_LOG_LINES {
            b.push(n.to_string());
        }
        let lines = b.lines();
        assert_eq!(lines.len(), MAX_LOG_LINES);
        assert_eq!(lines.last().unwrap(), &(MAX_LOG_LINES - 1).to_string());
    }

    #[test]
    fn more_lines_end_with_a_dropped_count_and_stay_within_the_limit() {
        let mut b = LogBuffer::default();
        for n in 0..120 {
            b.push(n.to_string());
        }
        let lines = b.lines();
        assert_eq!(lines.len(), MAX_LOG_LINES);
        assert_eq!(lines[MAX_LOG_LINES - 2], (MAX_LOG_LINES - 2).to_string());
        assert_eq!(
            lines[MAX_LOG_LINES - 1],
            format!("… {} lines dropped", 120 - 49)
        );
    }
}
