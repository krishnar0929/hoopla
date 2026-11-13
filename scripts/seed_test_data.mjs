#!/usr/bin/env node
// Creates TEST data in the hoopla-894ca Firebase project so every feature can be tried:
//   - 3 providers for every service type (photographers, designers, decorators, ...), with photos,
//     social links and featured reels
//   - 5 customers, each with a party plan (dates chosen so reminders fire soon)
//   - ratings & reviews from the customers, with replies from some providers
//   - a referral (Priya invited Rahul: both get a week of Pro) and a free trial (Anjali on Pro)
//   - one feedback message
//
// It signs in as each test account (email + password) and writes through the normal
// security rules, exactly like the app does. Everything is marked testData: true.
//
// Run:    node scripts/seed_test_data.mjs
// Remove: node scripts/seed_test_data.mjs --clean
// Needs Node 18+ and Firebase → Authentication → Email/Password turned on.

const API_KEY = 'AIzaSyAcw0neEX-OpFRZU7moI8dZnn0ZVojONCI';
const PROJECT = 'hoopla-894ca';
const PASSWORD = 'HooplaTest2026!';
const DOMAIN = 'hoopla-test.dev';
const DB = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const CLEAN = process.argv.includes('--clean');

// ---------------------------------------------------------------- test people

const CITIES = ['Edison, NJ', 'Iselin, NJ', 'Jersey City, NJ', 'Princeton, NJ', 'Piscataway, NJ', 'Parsippany, NJ', 'Plainsboro, NJ', 'Hoboken, NJ'];

// [business name, price range, about] × 3 per service type.
const PROVIDERS = {
  Photographers: [
    ['Lens & Laughter Studio', '$400–$900 per event', 'Candid kids\' birthdays and family events. 2 photographers, 300+ edited photos in 5 days.'],
    ['Golden Hour Clicks', '$600–$1,500', 'Wedding, sangeet and pooja photography. Drone shots available.'],
    ['Snapshot Sisters', '$350–$700', 'Fun, colourful party photos and a free 1-minute highlight reel.'],
  ],
  Videographers: [
    ['ReelTime Films', '$700–$1,800', 'Cinematic event films and Instagram reels delivered in 72 hours.'],
    ['Moments in Motion', '$500–$1,200', 'Birthday and anniversary videos with live streaming for family abroad.'],
    ['Story Reel Studio', '$900–$2,500', 'Wedding and sangeet films, same-day edits.'],
  ],
  Decorators: [
    ['Balloon Bliss NJ', '$250–$800', 'Balloon arches, garlands and themed backdrops. Setup and cleanup included.'],
    ['Royal Rangoli Decor', '$400–$1,500', 'Traditional flower and rangoli decor for poojas, housewarmings and haldi.'],
    ['Party Pop Decor', '$200–$600', 'Kids\' themes: dinosaurs, unicorns, superheroes, Bluey and more.'],
  ],
  'Stage decor': [
    ['Mandap Magic', '$1,200–$4,000', 'Mandaps and stages with LED backdrops and fresh flowers.'],
    ['Grand Stage Events', '$800–$2,500', 'Stage, lighting and photo-booth walls for sangeet and receptions.'],
    ['Floral Frame Studio', '$500–$1,500', 'Floral stage backdrops and entrance arches.'],
  ],
  'Event planners': [
    ['Celebrate Simply', '$500–$2,000', 'Full planning or day-of coordination for birthdays and baby showers.'],
    ['Utsav Planners', '$1,000–$5,000', 'Indian weddings, sangeet and big-family events, start to finish.'],
    ['Little Party Co.', '$300–$900', 'Kids\' parties planned in a week: theme, games host and return gifts.'],
  ],
  Designers: [
    ['Inkwell Invites', '$80–$300', 'Custom digital invites, WhatsApp e-cards and welcome boards.'],
    ['Pastel & Print', '$150–$500', 'Party branding: invites, banners, cake toppers and return-gift tags.'],
    ['Theme Studio Designs', '$200–$800', 'Full theme design: backdrop art, signage and table cards.'],
  ],
  'Cake makers': [
    ['Sugar Bloom Cakes', '$60–$400', 'Eggless theme cakes and cupcakes. Delivery in Middlesex County.'],
    ['The Cake Chowk', '$50–$300', 'Fusion flavours: rasmalai, mango and gulab jamun cakes.'],
    ['Frost & Fable', '$100–$600', 'Tiered celebration cakes and dessert tables.'],
  ],
  Panthulu: [
    ['Sri Venkateswara Pooja Services', '$150–$500', 'Gruhapravesam, Satyanarayana vratam and naming ceremonies. Telugu and Sanskrit.'],
    ['Pandit Sharma Ji', '$151–$501', 'Pooja, havan and wedding ceremonies. Hindi and English.'],
    ['Vedic Rituals NJ', '$200–$700', 'All samskaras; brings pooja samagri on request.'],
  ],
  Makeup: [
    ['Glam by Divya', '$120–$450', 'Bridal, party and saree draping. Travels to you.'],
    ['Blush & Bindi', '$80–$300', 'Party makeup and hairstyling; group bookings for sangeet.'],
    ['Studio Sundari', '$150–$600', 'HD and airbrush bridal makeup.'],
  ],
  'Cleaners & maids': [
    ['Sparkle After Party', '$120–$350', 'Before- and after-party cleaning, dishes included.'],
    ['Helping Hands Home Care', '$25/hour', 'Kitchen help and cleaning for home functions.'],
    ['FreshNest Cleaning', '$150–$400', 'Deep cleaning before housewarmings and poojas.'],
  ],
  Helpers: [
    ['Party Pals Staffing', '$25–$35/hour', 'Servers, kitchen helpers and setup crew.'],
    ['Extra Hands Events', '$30/hour', 'Friendly helpers for food service and games.'],
    ['Utsav Helpers', '$22–$30/hour', 'Hindi- and Telugu-speaking helpers for home events.'],
  ],
  Transport: [
    ['Baraat Rides', '$300–$1,200', 'Vintage cars and horse for baraat; party buses.'],
    ['Party Shuttle NJ', '$150–$600', 'Minibus pick-up and drop for guests.'],
    ['Royal Limo Service', '$200–$800', 'Limos and SUVs for birthdays and weddings.'],
  ],
  'Anchors / MC': [
    ['Emcee Arjun', '$300–$900', 'Bilingual host (English and Hindi) for sangeet and birthdays.'],
    ['Host with Hema', '$250–$700', 'Kids\' party host: games, quizzes and a lot of noise.'],
    ['Mic Drop Events', '$400–$1,200', 'Professional MCs for receptions and corporate parties.'],
  ],
  DJs: [
    ['DJ Bollywood Beats', '$400–$1,200', 'Bollywood, Tollywood and dance hits. Lights included.'],
    ['DJ Dhol Nation', '$600–$1,500', 'DJ with live dhol for baraat and sangeet.'],
    ['Kids Party DJ Sam', '$250–$500', 'Kids\' DJ with games, bubbles and freeze dance.'],
  ],
  Singers: [
    ['Swara Live', '$500–$1,500', 'Live Bollywood and ghazal evenings.'],
    ['Sangeet Sisters', '$400–$1,000', 'Sangeet and mehendi songs with dholak.'],
    ['Acoustic Anand', '$300–$800', 'Acoustic covers for anniversaries and dinners.'],
  ],
  Dancers: [
    ['Nritya Dance Crew', '$300–$1,200', 'Sangeet choreography and performances.'],
    ['Bhangra Bros', '$400–$1,000', 'High-energy bhangra performance and crowd workshop.'],
    ['Little Feet Dance', '$200–$500', 'Kids\' dance party host and mini-performances.'],
  ],
  Caterers: [
    ['Swagath Caterers', '$15–$30 per plate', 'South Indian and Andhra menus, live dosa station.'],
    ['Punjabi Tadka Catering', '$18–$35 per plate', 'North Indian buffets and live chaat counters.'],
    ['Spice Route Kitchen', '$20–$40 per plate', 'Indo-Chinese and fusion menus; kids\' menu available.'],
  ],
  Rentals: [
    ['Party Rent NJ', '$100–$800', 'Chairs, tables, tents and linens. Delivery and setup.'],
    ['Bounce House Bonanza', '$150–$400', 'Bounce houses and kids\' games for backyard parties.'],
    ['Royal Seating Rentals', '$300–$1,500', 'Throne chairs, sofas and lounge setups.'],
  ],
};

// Customers. Party dates are counted from today so reminders show up soon.
const CUSTOMERS = [
  { key: 'priya', name: 'Priya Sharma', occasion: 'Birthday', title: "Aarav's 5th Birthday", inDays: 8, guests: 35, audience: 'kids', indoor: true },
  { key: 'rahul', name: 'Rahul Verma', occasion: 'Housewarming', title: 'Verma Gruhapravesam', inDays: 21, guests: 60, audience: 'everyone', indoor: true },
  { key: 'anjali', name: 'Anjali Reddy', occasion: 'Baby shower', title: "Anjali's Seemantham", inDays: 3, guests: 40, audience: 'adults', indoor: true },
  { key: 'sameer', name: 'Sameer Khan', occasion: 'Anniversary', title: '10 Years of Sameer & Sara', inDays: 30, guests: 25, audience: 'adults', indoor: false },
  { key: 'meera', name: 'Meera Iyer', occasion: 'Get-together', title: 'Diwali Get-together', inDays: 1, guests: 20, audience: 'everyone', indoor: true },
];

// Reviews: [customer, service type, which provider (0-2), stars, comment]
const REVIEWS = [
  ['priya', 'Photographers', 0, 5, 'Captured every candid moment of the kids. Photos came in 4 days. Booking again!'],
  ['rahul', 'Photographers', 0, 5, 'Very patient with elders during the pooja. Lovely album.'],
  ['anjali', 'Photographers', 0, 4, 'Great photos, arrived 15 minutes late but stayed extra.'],
  ['sameer', 'Photographers', 1, 5, 'The drone shots of our garden party were stunning.'],
  ['meera', 'Photographers', 1, 3, 'Good photos but took 3 weeks to deliver.'],
  ['priya', 'Photographers', 2, 4, 'Fun and colourful, kids loved the highlight reel.'],
  ['priya', 'Decorators', 2, 5, 'The dinosaur theme was a hit. Setup in under an hour!'],
  ['rahul', 'Decorators', 1, 5, 'Beautiful marigold decor for our gruhapravesam. Fresh flowers, great rangoli.'],
  ['anjali', 'Decorators', 0, 4, 'Pretty pastel balloon arch, good value.'],
  ['meera', 'Decorators', 0, 5, 'Balloon garland looked like Pinterest. Cleaned up after too.'],
  ['sameer', 'Decorators', 1, 4, 'Elegant decor, slightly pricey.'],
  ['priya', 'Designers', 0, 5, 'Our WhatsApp invite got so many compliments.'],
  ['anjali', 'Designers', 1, 5, 'Matching banner, cake topper and gift tags. So cute.'],
  ['rahul', 'Designers', 2, 4, 'Nice welcome board, one round of edits needed.'],
  ['priya', 'Cake makers', 0, 5, 'Best eggless cake we\'ve had. The dino cake was perfect.'],
  ['meera', 'Cake makers', 1, 5, 'Rasmalai cake disappeared in 10 minutes!'],
  ['rahul', 'Panthulu', 0, 5, 'Explained every step of the gruhapravesam to the kids. Very punctual.'],
  ['anjali', 'Makeup', 0, 5, 'Divya made me look and feel amazing. Saree draping was perfect.'],
  ['sameer', 'DJs', 0, 4, 'Great playlist, everyone danced.'],
  ['priya', 'DJs', 2, 5, 'Freeze dance and bubbles: kids didn\'t want to go home.'],
  ['rahul', 'Caterers', 0, 5, 'Live dosa station was the star of the day.'],
];

// Provider replies: [service type, provider index, customer, reply]
const REPLIES = [
  ['Photographers', 0, 'priya', 'Thank you Priya! Aarav was the best model. 📸'],
  ['Photographers', 1, 'meera', 'Sorry for the wait, Meera. We\'ve added an extra editor so it\'s 7 days max now.'],
  ['Decorators', 2, 'priya', 'Roar-some party! Thanks for choosing us 🦖'],
];

// ---------------------------------------------------------------- helpers

const USER_FIELDS = ['role', 'email', 'name', 'testData'];
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 24);
const emailFor = (key) => `${key}@${DOMAIN}`;

async function call(url, body, token, method = 'POST') {
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (!res.ok) {
    const msg = json.error?.message || text;
    const err = new Error(`${res.status} ${msg}`);
    err.code = msg;
    throw err;
  }
  return json;
}

/** Signs in, creating the account the first time. Returns { uid, token }. */
async function account(key, displayName) {
  const email = emailFor(key);
  const auth = 'https://identitytoolkit.googleapis.com/v1/accounts';
  let r;
  try {
    r = await call(`${auth}:signUp?key=${API_KEY}`, { email, password: PASSWORD, returnSecureToken: true });
    await call(`${auth}:update?key=${API_KEY}`, { idToken: r.idToken, displayName, returnSecureToken: false });
    r = await call(`${auth}:signInWithPassword?key=${API_KEY}`, { email, password: PASSWORD, returnSecureToken: true });
  } catch (e) {
    if (!String(e.code).startsWith('EMAIL_EXISTS')) throw e;
    r = await call(`${auth}:signInWithPassword?key=${API_KEY}`, { email, password: PASSWORD, returnSecureToken: true });
  }
  return { uid: r.localId, token: r.idToken, email };
}

/** Plain JS → Firestore REST value. */
function v(x) {
  if (x === null || x === undefined) return { nullValue: null };
  if (x instanceof Date) return { timestampValue: x.toISOString() };
  if (Array.isArray(x)) return { arrayValue: { values: x.map(v) } };
  if (typeof x === 'boolean') return { booleanValue: x };
  if (typeof x === 'number') return Number.isInteger(x) ? { integerValue: String(x) } : { doubleValue: x };
  if (typeof x === 'object') return { mapValue: { fields: fields(x) } };
  return { stringValue: String(x) };
}
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, x]) => [k, v(x)]));
const docName = (path) => `projects/${PROJECT}/databases/(default)/documents/${path}`;

/** True when the document is there (false if missing or not readable). */
async function exists(token, path) {
  try {
    await call(`${DB}/${path}`, undefined, token, 'GET');
    return true;
  } catch (_) {
    return false;
  }
}

/** One write. serverTime = fields set to the server's clock; mustNotExist = create only. */
async function write(token, path, data, { serverTime = [], mask, mustNotExist = false } = {}) {
  const w = { update: { name: docName(path), fields: fields(data) } };
  if (mask) w.updateMask = { fieldPaths: mask };
  if (serverTime.length) w.updateTransforms = serverTime.map((f) => ({ fieldPath: f, setToServerValue: 'REQUEST_TIME' }));
  if (mustNotExist) {
    if (await exists(token, path)) return false; // Made by an earlier run.
    w.currentDocument = { exists: false };
  }
  try {
    await call(`${DB}:commit`, { writes: [w] }, token);
    return true;
  } catch (e) {
    // Already there from an earlier run: fine.
    if (mustNotExist && /ALREADY_EXISTS|already exists|PERMISSION_DENIED/i.test(String(e.code))) return false;
    throw e;
  }
}

async function remove(token, path) {
  try {
    await call(`${DB}/${path}`, undefined, token, 'DELETE');
  } catch (_) {}
}

async function list(token, path) {
  try {
    const r = await call(`${DB}/${path}?pageSize=300`, undefined, token, 'GET');
    return (r.documents || []).map((d) => d.name.split('/').pop());
  } catch (_) {
    return [];
  }
}

function eventDoc(c) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + c.inDays);
  const pad = (n) => String(n).padStart(2, '0');
  const local = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T00:00:00.000`;
  return {
    id: `test-${c.key}`,
    occasion: c.occasion,
    title: c.title,
    date: local,
    startMinutes: c.key === 'meera' ? 18 * 60 : 16 * 60,
    hours: 3,
    indoor: c.indoor,
    guests: c.guests,
    audience: c.audience,
    energy: 1,
    gameIds: [],
    doneTasks: c.key === 'rahul' ? ['invites'] : [],
    shortlist: [],
    savedLinks: [{ title: 'Instagram reel · Musical chairs twist', url: 'https://www.instagram.com/reel/C0example1/' }],
    taskReminders: {},
    budget: c.guests * 25,
    status: 'active',
    updatedAt: new Date().toISOString(),
  };
}

// ---------------------------------------------------------------- run

async function seed() {
  const providers = {}; // "Photographers#0" → { uid, token, name }
  let n = 0;
  console.log('Creating providers...');
  for (const [type, rows] of Object.entries(PROVIDERS)) {
    for (let i = 0; i < rows.length; i++) {
      const [name, price, about] = rows[i];
      const key = `pro-${slug(type)}-${i + 1}`;
      const a = await account(key, name);
      const handle = slug(name);
      const photos = Array.from({ length: 6 }, (_, p) => `https://picsum.photos/seed/${handle}${p}/900/700`);
      const city = CITIES[(n + i) % CITIES.length];
      await write(a.token, `users/${a.uid}`, { role: 'provider', email: a.email, name, testData: true }, { mask: USER_FIELDS, serverTime: ['updatedAt'] });
      await write(
        a.token,
        `providers/${a.uid}`,
        {
          uid: a.uid,
          businessName: name,
          serviceType: type,
          city,
          cityLower: city.toLowerCase(),
          phone: `+1 732 555 01${String(n % 100).padStart(2, '0')}`,
          priceRange: price,
          about,
          photos,
          instagram: i === 2 ? '' : handle,
          website: i === 0 ? `${handle}.example.com` : '',
          facebook: i === 1 ? handle : '',
          youtube: type.match(/Video|Photo|DJ|Singer|Dancer/) ? `@${handle}` : '',
          tiktok: i === 0 ? `@${handle}` : '',
          reviewsLink: i === 1 ? 'https://www.google.com/maps' : '',
          featured: i === 2 ? [] : ['https://www.instagram.com/reel/C0example1/', 'https://www.youtube.com/shorts/example2'],
          testData: true,
        },
        { serverTime: ['updatedAt'] },
      );
      providers[`${type}#${i}`] = { ...a, name };
      n++;
      process.stdout.write(`  ✓ ${type}: ${name}\n`);
    }
  }

  console.log('Creating customers and their parties...');
  const customers = {};
  for (const c of CUSTOMERS) {
    const a = await account(c.key, c.name);
    await write(a.token, `users/${a.uid}`, { role: 'customer', email: a.email, name: c.name, testData: true }, { mask: USER_FIELDS, serverTime: ['updatedAt'] });
    await write(a.token, `users/${a.uid}/events/test-${c.key}`, eventDoc(c));
    customers[c.key] = a;
    console.log(`  ✓ ${c.name}: "${c.title}" in ${c.inDays} day${c.inDays === 1 ? '' : 's'}`);
  }

  console.log('Adding reviews...');
  const cust = Object.fromEntries(CUSTOMERS.map((c) => [c.key, c]));
  for (const [ck, type, idx, stars, comment] of REVIEWS) {
    const p = providers[`${type}#${idx}`];
    const c = customers[ck];
    const first = cust[ck].name.split(' ');
    const made = await write(
      c.token,
      `providers/${p.uid}/reviews/${c.uid}`,
      { stars, comment, name: `${first[0]} ${first[first.length - 1][0]}.`, eventType: cust[ck].occasion, reply: '' },
      { serverTime: ['createdAt', 'updatedAt'], mustNotExist: true },
    );
    console.log(`  ${made ? '✓' : '·'} ${'★'.repeat(stars)}${'☆'.repeat(5 - stars)} ${cust[ck].name} → ${p.name}`);
  }

  console.log('Adding provider replies...');
  for (const [type, idx, ck, reply] of REPLIES) {
    const p = providers[`${type}#${idx}`];
    await write(p.token, `providers/${p.uid}/reviews/${customers[ck].uid}`, { reply }, { mask: ['reply', 'repliedAt'], serverTime: ['repliedAt'] });
    console.log(`  ✓ ${p.name} replied to ${cust[ck].name}`);
  }

  console.log('Referral: Priya invites Rahul...');
  const priya = customers.priya;
  const code = 'PRYA26';
  await write(priya.token, `refCodes/${code}`, { uid: priya.uid }, { serverTime: ['createdAt'], mustNotExist: true }).catch((e) => {
    console.log(`  (code ${code} belongs to someone else: ${e.message})`);
  });
  await write(priya.token, `users/${priya.uid}`, { refCode: code }, { mask: ['refCode'] });
  const used = await write(
    customers.rahul.token,
    `referrals/${customers.rahul.uid}`,
    { code, referrerUid: priya.uid },
    { serverTime: ['createdAt'], mustNotExist: true },
  );
  console.log(`  ${used ? '✓' : '·'} Rahul joined with code ${code}: Priya and Rahul both get 1 week of Pro`);

  console.log('Free trial: Anjali starts a 3-day Pro trial...');
  await write(customers.anjali.token, `users/${customers.anjali.uid}`, { trialPlan: 'pro' }, { mask: ['trialPlan'], serverTime: ['trialStartedAt'] }).catch(
    () => console.log('  · trial already used'),
  );

  console.log('Feedback from Sameer...');
  await write(
    customers.sameer.token,
    `feedback/test-${customers.sameer.uid}`,
    { uid: customers.sameer.uid, type: 'idea', rating: 4, message: 'Test feedback: please add a guest RSVP list!', email: null, plan: 'free', platform: 'script', appVersion: 'seed' },
    { serverTime: ['createdAt'], mustNotExist: true },
  );

  console.log(`
Done! Every test account uses the password:  ${PASSWORD}

Customers (sign in with these to try things):
  priya@${DOMAIN}   Pro for a week (referred Rahul). Party in 8 days. Has written reviews.
  rahul@${DOMAIN}   Pro for a week (used Priya's code). Housewarming in 21 days.
  anjali@${DOMAIN}  Pro free trial (3 days). Baby shower in 3 days.
  sameer@${DOMAIN}  Free plan. Shows the Nearby lock and the upgrade page.
  meera@${DOMAIN}   Free plan. Party is TOMORROW: good for the countdown reminders.

Providers (3 per service type), e.g.:
  pro-photographers-1@${DOMAIN}   Lens & Laughter Studio (3 reviews, replied to Priya)
  pro-decorators-3@${DOMAIN}      Party Pop Decor
  pro-designers-1@${DOMAIN}       Inkwell Invites
  Pattern: pro-<servicetype>-<1|2|3>@${DOMAIN}

Remove everything later:  node scripts/seed_test_data.mjs --clean
`);
}

async function clean() {
  const signIn = (key) =>
    call(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
      email: emailFor(key),
      password: PASSWORD,
      returnSecureToken: true,
    }).then((r) => ({ key, uid: r.localId, token: r.idToken }), () => null);

  const proKeys = [];
  for (const [type, rows] of Object.entries(PROVIDERS)) rows.forEach((_, i) => proKeys.push(`pro-${slug(type)}-${i + 1}`));
  const pros = (await Promise.all(proKeys.map(signIn))).filter(Boolean);
  const custs = (await Promise.all(CUSTOMERS.map((c) => signIn(c.key)))).filter(Boolean);

  // Reviews can only be deleted by the person who wrote them.
  for (const c of custs) {
    for (const p of pros) await remove(c.token, `providers/${p.uid}/reviews/${c.uid}`);
  }
  for (const a of [...custs, ...pros]) {
    for (const id of await list(a.token, `users/${a.uid}/events`)) await remove(a.token, `users/${a.uid}/events/${id}`);
    await remove(a.token, `providers/${a.uid}`);
    await remove(a.token, `users/${a.uid}`);
    await call(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`, { idToken: a.token }).catch(() => {});
    console.log(`  ✓ removed ${emailFor(a.key)}`);
  }
  console.log('\nDone. The app\'s rules don\'t allow deleting refCodes/PRYA26, the referral and the test feedback;');
  console.log('delete those in the Firebase console (Firestore) if you want them gone.');
}

(CLEAN ? clean() : seed()).catch((e) => {
  console.error(`\n✗ ${e.message}`);
  if (/OPERATION_NOT_ALLOWED/.test(e.message)) console.error('  Turn on Firebase → Authentication → Sign-in method → Email/Password.');
  if (/PERMISSION_DENIED/.test(e.message)) console.error('  Deploy the latest rules first: firebase deploy --only firestore:rules');
  if (/TOO_MANY_ATTEMPTS/.test(e.message)) console.error('  Firebase limits new accounts per hour. Wait an hour and run again; it picks up where it stopped.');
  process.exit(1);
});
