// Dựng assets/icon/*.png từ logo của IKiot-FE. Chạy từ thư mục IKiot-FE (cần sharp trong node_modules của nó):
//   cd IKiot-FE && node ../IKiot-MOBILE/tool/make-icons.js "$PWD/node_modules/.pnpm/sharp@0.34.5/node_modules/sharp" ../IKiot-MOBILE/assets/icon
// rồi trong IKiot-MOBILE: dart run flutter_launcher_icons
// Thêm tham số thứ ba (thư mục res của Android) để dựng luôn icon nhỏ của thông báo đẩy:
//   ... ../IKiot-MOBILE/assets/icon ../IKiot-MOBILE/android/app/src/main/res
const fs = require('fs');
const sharp = require(process.argv[2]);
const out = process.argv[3];
const androidRes = process.argv[4];
const tsx = fs.readFileSync('src/components/logo.tsx', 'utf8');
// Lấy phần thân <svg>…</svg>: các path và circle, thay currentColor bằng trắng.
const inner = tsx.slice(tsx.indexOf('<path'), tsx.lastIndexOf('</svg>')).replace(/currentColor/g, '#ffffff');
const BG = '#171717'; // primary của FE: oklch(0.205 0 0)

// scale: logo chiếm bao nhiêu phần của ô 1024.
const svg = (scale, background) => {
  const size = 1024 * scale, off = (1024 - size) / 2, k = size / 32;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    ${background ? `<rect width="1024" height="1024" fill="${BG}"/>` : ''}
    <g fill="none" transform="translate(${off} ${off}) scale(${k})">${inner}</g></svg>`;
};

(async () => {
  // Icon đầy đủ (iOS, Android cũ): iOS tự bo góc, nên nền phủ kín ô.
  await sharp(Buffer.from(svg(0.62, true))).png().toFile(`${out}/icon.png`);
  // Foreground của adaptive icon Android. flutter_launcher_icons tự bọc nó trong inset 16% (còn 68% cạnh),
  // nên 0.72 ở đây ≈ logo rộng 49% icon - vẫn trong vùng an toàn hình tròn (66%) mà launcher không cắt.
  await sharp(Buffer.from(svg(0.72, false))).png().toFile(`${out}/icon-foreground.png`);
  // Logo trơn trong app (màn đăng nhập); app tự tô màu theo theme.
  await sharp(Buffer.from(svg(1, false))).resize(256, 256).png().toFile(`${out}/logo.png`);
  // Icon nhỏ trên thanh trạng thái khi có push: Android chỉ lấy kênh alpha (hình trắng trên nền trong),
  // dùng icon launcher có nền đặc thì chỉ hiện một ô vuông trắng. 24dp theo từng mật độ.
  if (androidRes) {
    const densities = { mdpi: 24, hdpi: 36, xhdpi: 48, xxhdpi: 72, xxxhdpi: 96 };
    for (const [density, px] of Object.entries(densities)) {
      fs.mkdirSync(`${androidRes}/drawable-${density}`, { recursive: true });
      await sharp(Buffer.from(svg(0.84, false))).resize(px, px).png()
        .toFile(`${androidRes}/drawable-${density}/ic_notification.png`);
    }
  }
  console.log('ok');
})();
