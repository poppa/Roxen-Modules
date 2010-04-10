
$(document).ready(function() {
  $('table.gallery td').each(function(i, el) {
    $(el).mouseenter(function(e) {
      e.stopPropagation();
      $(this).find('span.flickr-go').slideDown('fast');
    }).mouseleave(function(e) {
      e.stopPropagation();
      $(this).find('span.flickr-go').slideUp('fast');
    });
  });
});