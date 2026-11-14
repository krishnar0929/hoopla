// Sample providers and reviews shown in Nearby so people can see how Hoopla
// listings look before real providers in their area join. Generated from
// scripts/seed_test_data.mjs. Turn off with [showSampleProviders].

import '../models/provider_profile.dart';
import '../services/review_service.dart';

/// Fill Nearby with sample listings when a service has fewer than 3 real providers.
const showSampleProviders = true;

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

/// Rough centers of the sample cities, for "x mi away".
const _cityCoords = <String, (double, double)>{
  'Edison, NJ': (40.5187, -74.4121),
  'Iselin, NJ': (40.5754, -74.3224),
  'Jersey City, NJ': (40.7178, -74.0431),
  'Princeton, NJ': (40.3573, -74.6672),
  'Piscataway, NJ': (40.5546, -74.4643),
  'Parsippany, NJ': (40.8579, -74.4260),
  'Plainsboro, NJ': (40.3337, -74.5810),
  'Hoboken, NJ': (40.7440, -74.0324),
};

const _cities = ['Edison, NJ', 'Iselin, NJ', 'Jersey City, NJ', 'Princeton, NJ', 'Piscataway, NJ', 'Parsippany, NJ', 'Plainsboro, NJ', 'Hoboken, NJ'];

/// [business name, price range, about] × 3 per service type.
const _samples = <String, List<List<String>>>{
  'Photographers': [
    ['Lens & Laughter Studio', '\$400–\$900 per event', 'Candid kids\' birthdays and family events. 2 photographers, 300+ edited photos in 5 days.'],
    ['Golden Hour Clicks', '\$600–\$1,500', 'Wedding, sangeet and pooja photography. Drone shots available.'],
    ['Snapshot Sisters', '\$350–\$700', 'Fun, colourful party photos and a free 1-minute highlight reel.'],
  ],
  'Videographers': [
    ['ReelTime Films', '\$700–\$1,800', 'Cinematic event films and Instagram reels delivered in 72 hours.'],
    ['Moments in Motion', '\$500–\$1,200', 'Birthday and anniversary videos with live streaming for family abroad.'],
    ['Story Reel Studio', '\$900–\$2,500', 'Wedding and sangeet films, same-day edits.'],
  ],
  'Decorators': [
    ['Balloon Bliss NJ', '\$250–\$800', 'Balloon arches, garlands and themed backdrops. Setup and cleanup included.'],
    ['Royal Rangoli Decor', '\$400–\$1,500', 'Traditional flower and rangoli decor for poojas, housewarmings and haldi.'],
    ['Party Pop Decor', '\$200–\$600', 'Kids\' themes: dinosaurs, unicorns, superheroes, Bluey and more.'],
  ],
  'Stage decor': [
    ['Mandap Magic', '\$1,200–\$4,000', 'Mandaps and stages with LED backdrops and fresh flowers.'],
    ['Grand Stage Events', '\$800–\$2,500', 'Stage, lighting and photo-booth walls for sangeet and receptions.'],
    ['Floral Frame Studio', '\$500–\$1,500', 'Floral stage backdrops and entrance arches.'],
  ],
  'Event planners': [
    ['Celebrate Simply', '\$500–\$2,000', 'Full planning or day-of coordination for birthdays and baby showers.'],
    ['Utsav Planners', '\$1,000–\$5,000', 'Indian weddings, sangeet and big-family events, start to finish.'],
    ['Little Party Co.', '\$300–\$900', 'Kids\' parties planned in a week: theme, games host and return gifts.'],
  ],
  'Designers': [
    ['Inkwell Invites', '\$80–\$300', 'Custom digital invites, WhatsApp e-cards and welcome boards.'],
    ['Pastel & Print', '\$150–\$500', 'Party branding: invites, banners, cake toppers and return-gift tags.'],
    ['Theme Studio Designs', '\$200–\$800', 'Full theme design: backdrop art, signage and table cards.'],
  ],
  'Cake makers': [
    ['Sugar Bloom Cakes', '\$60–\$400', 'Eggless theme cakes and cupcakes. Delivery in Middlesex County.'],
    ['The Cake Chowk', '\$50–\$300', 'Fusion flavours: rasmalai, mango and gulab jamun cakes.'],
    ['Frost & Fable', '\$100–\$600', 'Tiered celebration cakes and dessert tables.'],
  ],
  'Panthulu': [
    ['Sri Venkateswara Pooja Services', '\$150–\$500', 'Gruhapravesam, Satyanarayana vratam and naming ceremonies. Telugu and Sanskrit.'],
    ['Pandit Sharma Ji', '\$151–\$501', 'Pooja, havan and wedding ceremonies. Hindi and English.'],
    ['Vedic Rituals NJ', '\$200–\$700', 'All samskaras; brings pooja samagri on request.'],
  ],
  'Makeup': [
    ['Glam by Divya', '\$120–\$450', 'Bridal, party and saree draping. Travels to you.'],
    ['Blush & Bindi', '\$80–\$300', 'Party makeup and hairstyling; group bookings for sangeet.'],
    ['Studio Sundari', '\$150–\$600', 'HD and airbrush bridal makeup.'],
  ],
  'Cleaners & maids': [
    ['Sparkle After Party', '\$120–\$350', 'Before- and after-party cleaning, dishes included.'],
    ['Helping Hands Home Care', '\$25/hour', 'Kitchen help and cleaning for home functions.'],
    ['FreshNest Cleaning', '\$150–\$400', 'Deep cleaning before housewarmings and poojas.'],
  ],
  'Helpers': [
    ['Party Pals Staffing', '\$25–\$35/hour', 'Servers, kitchen helpers and setup crew.'],
    ['Extra Hands Events', '\$30/hour', 'Friendly helpers for food service and games.'],
    ['Utsav Helpers', '\$22–\$30/hour', 'Hindi- and Telugu-speaking helpers for home events.'],
  ],
  'Transport': [
    ['Baraat Rides', '\$300–\$1,200', 'Vintage cars and horse for baraat; party buses.'],
    ['Party Shuttle NJ', '\$150–\$600', 'Minibus pick-up and drop for guests.'],
    ['Royal Limo Service', '\$200–\$800', 'Limos and SUVs for birthdays and weddings.'],
  ],
  'Anchors / MC': [
    ['Emcee Arjun', '\$300–\$900', 'Bilingual host (English and Hindi) for sangeet and birthdays.'],
    ['Host with Hema', '\$250–\$700', 'Kids\' party host: games, quizzes and a lot of noise.'],
    ['Mic Drop Events', '\$400–\$1,200', 'Professional MCs for receptions and corporate parties.'],
  ],
  'DJs': [
    ['DJ Bollywood Beats', '\$400–\$1,200', 'Bollywood, Tollywood and dance hits. Lights included.'],
    ['DJ Dhol Nation', '\$600–\$1,500', 'DJ with live dhol for baraat and sangeet.'],
    ['Kids Party DJ Sam', '\$250–\$500', 'Kids\' DJ with games, bubbles and freeze dance.'],
  ],
  'Singers': [
    ['Swara Live', '\$500–\$1,500', 'Live Bollywood and ghazal evenings.'],
    ['Sangeet Sisters', '\$400–\$1,000', 'Sangeet and mehendi songs with dholak.'],
    ['Acoustic Anand', '\$300–\$800', 'Acoustic covers for anniversaries and dinners.'],
  ],
  'Dancers': [
    ['Nritya Dance Crew', '\$300–\$1,200', 'Sangeet choreography and performances.'],
    ['Bhangra Bros', '\$400–\$1,000', 'High-energy bhangra performance and crowd workshop.'],
    ['Little Feet Dance', '\$200–\$500', 'Kids\' dance party host and mini-performances.'],
  ],
  'Caterers': [
    ['Swagath Caterers', '\$15–\$30 per plate', 'South Indian and Andhra menus, live dosa station.'],
    ['Punjabi Tadka Catering', '\$18–\$35 per plate', 'North Indian buffets and live chaat counters.'],
    ['Spice Route Kitchen', '\$20–\$40 per plate', 'Indo-Chinese and fusion menus; kids\' menu available.'],
  ],
  'Rentals': [
    ['Party Rent NJ', '\$100–\$800', 'Chairs, tables, tents and linens. Delivery and setup.'],
    ['Bounce House Bonanza', '\$150–\$400', 'Bounce houses and kids\' games for backyard parties.'],
    ['Royal Seating Rentals', '\$300–\$1,500', 'Throne chairs, sofas and lounge setups.'],
  ],
};

/// Sample reviews: [service type, provider index, name, event type, stars, comment, reply].
const _reviews = <List<Object>>[
  ['Photographers', 0, 'Priya S.', 'Birthday', 5, 'Captured every candid moment of the kids. Photos came in 4 days. Booking again!', 'Thank you Priya! Aarav was the best model. 📸'],
  ['Photographers', 0, 'Rahul V.', 'Housewarming', 5, 'Very patient with elders during the pooja. Lovely album.', ''],
  ['Photographers', 0, 'Anjali R.', 'Baby shower', 4, 'Great photos, arrived 15 minutes late but stayed extra.', ''],
  ['Photographers', 1, 'Sameer K.', 'Anniversary', 5, 'The drone shots of our garden party were stunning.', ''],
  ['Photographers', 1, 'Meera I.', 'Get-together', 3, 'Good photos but took 3 weeks to deliver.', 'Sorry for the wait, Meera. We\'ve added an extra editor so it\'s 7 days max now.'],
  ['Photographers', 2, 'Priya S.', 'Birthday', 4, 'Fun and colourful, kids loved the highlight reel.', ''],
  ['Decorators', 2, 'Priya S.', 'Birthday', 5, 'The dinosaur theme was a hit. Setup in under an hour!', 'Roar-some party! Thanks for choosing us 🦖'],
  ['Decorators', 1, 'Rahul V.', 'Housewarming', 5, 'Beautiful marigold decor for our gruhapravesam. Fresh flowers, great rangoli.', ''],
  ['Decorators', 0, 'Anjali R.', 'Baby shower', 4, 'Pretty pastel balloon arch, good value.', ''],
  ['Decorators', 0, 'Meera I.', 'Get-together', 5, 'Balloon garland looked like Pinterest. Cleaned up after too.', ''],
  ['Decorators', 1, 'Sameer K.', 'Anniversary', 4, 'Elegant decor, slightly pricey.', ''],
  ['Designers', 0, 'Priya S.', 'Birthday', 5, 'Our WhatsApp invite got so many compliments.', ''],
  ['Designers', 1, 'Anjali R.', 'Baby shower', 5, 'Matching banner, cake topper and gift tags. So cute.', ''],
  ['Designers', 2, 'Rahul V.', 'Housewarming', 4, 'Nice welcome board, one round of edits needed.', ''],
  ['Cake makers', 0, 'Priya S.', 'Birthday', 5, 'Best eggless cake we\'ve had. The dino cake was perfect.', ''],
  ['Cake makers', 1, 'Meera I.', 'Get-together', 5, 'Rasmalai cake disappeared in 10 minutes!', ''],
  ['Panthulu', 0, 'Rahul V.', 'Housewarming', 5, 'Explained every step of the gruhapravesam to the kids. Very punctual.', ''],
  ['Makeup', 0, 'Anjali R.', 'Baby shower', 5, 'Divya made me look and feel amazing. Saree draping was perfect.', ''],
  ['DJs', 0, 'Sameer K.', 'Anniversary', 4, 'Great playlist, everyone danced.', ''],
  ['DJs', 2, 'Priya S.', 'Birthday', 5, 'Freeze dance and bubbles: kids didn\'t want to go home.', ''],
  ['Caterers', 0, 'Rahul V.', 'Housewarming', 5, 'Live dosa station was the star of the day.', ''],
];

String sampleId(String type, int i) => 'sample-${_slug(type)}-${i + 1}';

/// The 3 sample listings for a service type (empty if there are none).
List<ProviderProfile> sampleProvidersFor(String type) {
  final rows = _samples[type];
  if (rows == null) return const [];
  final offset = _samples.keys.toList().indexOf(type);
  return [
    for (var i = 0; i < rows.length; i++)
      ProviderProfile(
        uid: sampleId(type, i),
        businessName: rows[i][0],
        serviceType: type,
        city: _cities[(offset * 3 + i) % _cities.length],
        lat: _cityCoords[_cities[(offset * 3 + i) % _cities.length]]?.$1,
        lng: _cityCoords[_cities[(offset * 3 + i) % _cities.length]]?.$2,
        phone: '',
        priceRange: rows[i][1],
        about: rows[i][2],
        photos: [for (var p = 0; p < 6; p++) 'https://picsum.photos/seed/${_slug(rows[i][0])}$p/900/700'],
        instagram: i == 2 ? '' : _slug(rows[i][0]),
        website: i == 0 ? '${_slug(rows[i][0])}.example.com' : '',
        featured: i == 2 ? const [] : const ['https://www.instagram.com/reel/C0example1/', 'https://www.youtube.com/shorts/example2'],
      ),
  ];
}

/// Reviews shown on a sample listing, newest first.
List<Review> sampleReviewsFor(String providerUid) {
  final now = DateTime.now();
  var n = 0;
  return [
    for (final r in _reviews)
      if (sampleId(r[0] as String, r[1] as int) == providerUid)
        Review(
          reviewerUid: 'sample-reviewer-${n++}',
          name: r[2] as String,
          eventType: r[3] as String,
          stars: r[4] as int,
          comment: r[5] as String,
          reply: r[6] as String,
          createdAt: now.subtract(Duration(days: 9 + n * 17)),
        ),
  ];
}

RatingSummary sampleSummaryFor(String providerUid) {
  final list = sampleReviewsFor(providerUid);
  if (list.isEmpty) return RatingSummary.none;
  return RatingSummary(list.fold<int>(0, (a, r) => a + r.stars) / list.length, list.length);
}
