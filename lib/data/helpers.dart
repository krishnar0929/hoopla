/// Kinds of nearby helpers, with the phrase used to search for them on maps.
class HelperCategory {
  const HelperCategory(this.label, this.search);
  final String label;
  final String search;

  Uri get mapsSearch =>
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$search near me'});
}

const helperCategories = <HelperCategory>[
  HelperCategory('Photographers', 'event photographer'),
  HelperCategory('Videographers', 'event videographer'),
  HelperCategory('Decorators', 'party decorator'),
  HelperCategory('Stage decor', 'stage decoration'),
  HelperCategory('Event planners', 'event planner'),
  HelperCategory('Designers', 'event designer'),
  HelperCategory('Cake makers', 'custom cake bakery'),
  HelperCategory('Panthulu', 'pandit panthulu priest'),
  HelperCategory('Makeup', 'makeup artist'),
  HelperCategory('Cleaners & maids', 'house cleaning service'),
  HelperCategory('Helpers', 'event staff helpers'),
  HelperCategory('Transport', 'party bus van rental'),
  HelperCategory('Anchors / MC', 'event anchor emcee'),
  HelperCategory('DJs', 'DJ for parties'),
  HelperCategory('Singers', 'live singer for events'),
  HelperCategory('Dancers', 'dance performers for events'),
  HelperCategory('Caterers', 'indian caterers'),
  HelperCategory('Rentals', 'party rentals chairs tables'),
];

/// Helpers most events of each kind need.
const helpersByOccasion = <String, List<String>>{
  'Birthday': ['Photographers', 'Decorators', 'Cake makers', 'Cleaners & maids'],
  'Housewarming': ['Panthulu', 'Caterers', 'Decorators', 'Photographers'],
  'Baby shower': ['Photographers', 'Decorators', 'Makeup', 'Caterers'],
  'Pooja': ['Panthulu', 'Caterers', 'Decorators', 'Cleaners & maids'],
  'Anniversary': ['Photographers', 'Cake makers', 'Decorators', 'Singers'],
  'Get-together': ['Caterers', 'Anchors / MC', 'Rentals', 'Cleaners & maids'],
};
