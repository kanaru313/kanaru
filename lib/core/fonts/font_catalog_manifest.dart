class CatalogFontItem {
  const CatalogFontItem({
    required this.id,
    required this.label,
    required this.family,
    required this.category,
    required this.designer,
    required this.license,
    required this.filename,
    required this.sizeBytes,
    required this.sha256,
    required this.previewSvgAsset,
  });

  final String id;
  final String label;
  final String family;
  final String category; // sans-serif, serif, monospace
  final String designer;
  final String license; // must match the license file inside the zip
  final String filename;
  final int sizeBytes; // size of the zip asset
  final String sha256; // sha256 of the zip asset
  final String previewSvgAsset;

  String get downloadUrl =>
      'https://github.com/kanaru313/kanaru/releases/download/fonts-v1/$filename';

  String get formattedSize => '${(sizeBytes / 1024).round()} KB';
}

const catalogFontsManifest = <CatalogFontItem>[
  CatalogFontItem(
    id: 'be-vietnam-pro',
    label: 'Be Vietnam Pro',
    family: 'Be Vietnam Pro',
    category: 'sans-serif',
    designer: 'Tiêu Trúc, Fábio Hà',
    license: 'OFL-1.1',
    filename: 'be-vietnam-pro.zip',
    sizeBytes: 163645,
    sha256: 'e5341153de3e3d278b7c9ee1a281b616ebf3926c9274f93893b209f4ad354bdf',
    previewSvgAsset: 'assets/font_previews/be_vietnam_pro.svg',
  ),
  CatalogFontItem(
    id: 'plus-jakarta-sans',
    label: 'Plus Jakarta Sans',
    family: 'Plus Jakarta Sans',
    category: 'sans-serif',
    designer: 'Gumpita Rahayu (Tokotype)',
    license: 'OFL-1.1',
    filename: 'plus-jakarta-sans.zip',
    sizeBytes: 176143,
    sha256: '2ba2689b19f1ac9b290328fa258052e1b968a430ec67c923dbd18287151ef0a2',
    previewSvgAsset: 'assets/font_previews/plus_jakarta_sans.svg',
  ),
  CatalogFontItem(
    id: 'roboto',
    label: 'Roboto',
    family: 'Roboto',
    category: 'sans-serif',
    designer: 'Christian Robertson (Google)',
    license: 'Apache-2.0',
    filename: 'roboto.zip',
    sizeBytes: 787537,
    sha256: 'fb86c81541ca97c5fc031e7a7882252a415f6ddf1ce3c7125a475983ad3eb346',
    previewSvgAsset: 'assets/font_previews/roboto.svg',
  ),
  CatalogFontItem(
    id: 'lexend',
    label: 'Lexend',
    family: 'Lexend',
    category: 'sans-serif',
    designer: 'Thomas Jockin',
    license: 'OFL-1.1',
    filename: 'lexend.zip',
    sizeBytes: 153908,
    sha256: '6af0773acfa6a58577cc9d7bcc76398ac6f6ae638b76d1281a94ec12bb425ec9',
    previewSvgAsset: 'assets/font_previews/lexend.svg',
  ),
  CatalogFontItem(
    id: 'lora',
    label: 'Lora',
    family: 'Lora',
    category: 'serif',
    designer: 'Cyreal',
    license: 'OFL-1.1',
    filename: 'lora.zip',
    sizeBytes: 311282,
    sha256: '1ea53f80c9e3a0357a3e2160afebe277938d5cad5c92ffb4a78e94b137aaa65d',
    previewSvgAsset: 'assets/font_previews/lora.svg',
  ),
  CatalogFontItem(
    id: 'fira-sans',
    label: 'Fira Sans',
    family: 'Fira Sans',
    category: 'sans-serif',
    designer: 'Carrois Apostrophe',
    license: 'OFL-1.1',
    filename: 'fira-sans.zip',
    sizeBytes: 636815,
    sha256: '49713adbbd60bd084264ae015b62019bd7cf2b62d750efa4633b1f950d2b0fe4',
    previewSvgAsset: 'assets/font_previews/fira_sans.svg',
  ),
  CatalogFontItem(
    id: 'jetbrains-mono',
    label: 'JetBrains Mono',
    family: 'JetBrains Mono',
    category: 'monospace',
    designer: 'JetBrains',
    license: 'OFL-1.1',
    filename: 'jetbrains-mono.zip',
    sizeBytes: 389710,
    sha256: '20d500b78085c9600489c33ae39d9fe6aa524ec3bbf749a25fd3eaccc8b3c657',
    previewSvgAsset: 'assets/font_previews/jetbrains_mono.svg',
  ),
];
