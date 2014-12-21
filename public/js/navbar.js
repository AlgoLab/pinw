$(window).load(function() {
  $('#login').on('shown.bs.modal', function () {
    $(this).find("[autofocus]:first").focus();
  });

  $("[data-toggle=tooltip]").tooltip();
});
