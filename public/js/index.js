function querystring(key) {
  var re=new RegExp('(?:\\?|&)'+key+'=(.*?)(?=&|$)','gi');
  var r=[], m;
  while ((m=re.exec(document.location.search)) !== null) r.push(m[1]);
  return r;
}
var querystring = querystring('err');

if (querystring.length) {
  $(window).load(function(){$('#login').modal('show');});
}


$(window).load(function() {
  $('.modal').on('shown.bs.modal', function () {
    $(this).find("[autofocus]:first").focus();
  });
});
