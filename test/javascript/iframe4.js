(function() {
  Turbolinks.cache('cachekey' , 'legal footer');

  return {
    data: { heading: 'Some heading 3', footer: Turbolinks.cache('cachekey') },
    title: 'title 3',
    csrf_token: 'token',
    assets: ['application-123.js', 'application-123.js']
  };
})();
