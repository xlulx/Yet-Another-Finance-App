// Makes the Google Play images from raw app screenshots: phone screenshots
// with a caption (1080x1920, 9:16) and the feature graphic (1024x500), in
// Turkish and English. JPEG, as Play does not accept transparent PNGs.
//
//   SHOT_DIR=/tmp/raw SHOT_HEIGHT=1920 flutter test test_screens/screens_test.dart
//   node store/compose.js /tmp/raw
//
// Needs Playwright with Chromium.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const raw = process.argv[2];
const outDir = path.join(__dirname, 'images');

const shots = [
  ['1_records', 'Gelir ve giderleriniz bir bakışta', 'Your money at a glance'],
  ['3_stats', 'Paranız nereye gidiyor, görün', 'See where your money goes'],
  ['3k_year_net', 'Ay ay ne kadar biriktirdiğinizi görün', 'See how much you save, month by month'],
  ['6_wallets', 'Nakit, banka, kart: hepsi bir arada', 'Cash, bank and cards in one place'],
  ['8_debts', 'Borçlarınızı ve alacaklarınızı takip edin', 'Keep track of what you lent and borrowed'],
  ['5b_recurring', 'Kira, maaş, abonelik kendiliğinden eklenir', 'Rent, salary, subscriptions added for you'],
  ['4b_settings', 'Hatırlatmalar ve kolay yedekleme', 'Reminders and easy backups'],
];

const tagline = {
  tr: ['Sade ve gizli bütçe takibi', 'Reklamsız · İnternetsiz · Verileriniz telefonda'],
  en: ['Simple, private budget tracker', 'No ads · No internet · Your data stays on your phone'],
};

const css = `
  * { margin: 0; box-sizing: border-box; }
  body { font-family: Inter, sans-serif; color: #fff;
         background: linear-gradient(160deg, #3A9A84 0%, #1F5E50 100%); }`;

const dataUrl = (file) =>
  'data:image/png;base64,' + fs.readFileSync(file).toString('base64');

function screenshotPage(caption, image) {
  return `<html><head><style>${css}
    .page { width: 1080px; height: 1920px; display: flex; flex-direction: column;
            align-items: center; }
    h1 { font-size: 66px; font-weight: 700; line-height: 1.15; text-align: center;
         letter-spacing: -0.5px; padding: 120px 90px 0; height: 400px; }
    img { width: 790px; border-radius: 44px; display: block;
          box-shadow: 0 30px 80px rgba(0,0,0,.35);
          border: 10px solid #0F2F28; }
  </style></head><body><div class="page">
    <h1>${caption}</h1><img src="${image}">
  </div></body></html>`;
}

function featurePage(lang, icon, phone) {
  const [title, sub] = tagline[lang];
  return `<html><head><style>${css}
    .page { width: 1024px; height: 500px; position: relative; overflow: hidden; }
    .text { position: absolute; left: 80px; top: 120px; width: 560px; }
    .brand { display: flex; align-items: center; gap: 26px; }
    .brand img { width: 110px; height: 110px; border-radius: 28px;
                 box-shadow: 0 10px 30px rgba(0,0,0,.25); }
    .brand span { font-size: 92px; font-weight: 800; letter-spacing: -1px; }
    h2 { font-size: 40px; font-weight: 600; margin-top: 28px; }
    p { font-size: 24px; margin-top: 14px; opacity: .85; }
    .phone { position: absolute; right: 70px; top: 60px; width: 270px;
             border-radius: 30px; border: 8px solid #0F2F28;
             box-shadow: 0 20px 60px rgba(0,0,0,.35); }
  </style></head><body><div class="page">
    <div class="text">
      <div class="brand"><img src="${icon}"><span>YASBA</span></div>
      <h2>${title}</h2><p>${sub}</p>
    </div>
    <img class="phone" src="${phone}">
  </div></body></html>`;
}

(async () => {
  const browser = await chromium.launch();
  const render = async (html, width, height, file) => {
    const page = await browser.newPage({ viewport: { width, height } });
    await page.setContent(html);
    await page.evaluate(() => document.fonts.ready);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await page.screenshot({ path: file, type: 'jpeg', quality: 92 });
    await page.close();
  };
  const icon = dataUrl(path.join(__dirname, 'icon-512.png'));
  for (const lang of ['tr', 'en']) {
    for (const [i, [name, tr, en]] of shots.entries()) {
      const image = dataUrl(path.join(raw, `${lang}_${name}.png`));
      await render(screenshotPage(lang === 'tr' ? tr : en, image), 1080, 1920,
        path.join(outDir, lang, `phone-${i + 1}.jpg`));
    }
    const phone = dataUrl(path.join(raw, `${lang}_1_records.png`));
    await render(featurePage(lang, icon, phone), 1024, 500,
      path.join(outDir, lang, 'feature-graphic.jpg'));
  }
  await browser.close();
})();
