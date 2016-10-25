var options = {
        feedbackIcons: {
            required: 'fa fa-asterisk',
            valid: 'fa fa-check',
            invalid: 'fa fa-times',
            validating: 'fa fa-refresh'
        },
        submitButtons: 'button[type="server"]',
        fields: {
            InputName: {
                validators: {
                    notEmpty: {
                        message: 'The name is required'
                    },
                    stringLength: {
                        min: 3,
                        max: 40,
                        message: 'The full name must be more than 3 and less than 40 characters'
                    }
                }
            },
            InputHost: {
                validators: {
                    notEmpty: {
                        message: 'The hostname is required'
                    },
                    regexp: {
                        regexp: /((^\s*((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\s*$)|(^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$))|(^\s*((?=.{1,255}$)(?=.*[A-Za-z].*)[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?)*)\s*$)/,
                        message: 'You can use IPv4, IPv6 or host name'
                    }
                }
            },
            InputPort: {
                validators: {
                    integer: {
                        message: 'The value is not an integer'
                    }
                }
            },
            InputUsername: {
                validators: {
                    notEmpty: {
                        message: 'The username is required'
                    }
                }
            },
            InputPassword: {
                validators: {
                    notEmpty: {
                        message: 'The password is required'
                    }
                }
            },
            InputCallbackURL: {
                validators: {
                    uri: {
                        message: 'The URL is not valid'
                    }
                }
            },
            InputPintronPath: {
              validators: {
                  notEmpty: {
                      message: 'Pintron Path is required'
                  }
              }
            }
        }
    };

$(document).ready(function() {
    $("[data-toggle=tooltip]").tooltip();
    $("input[name='type']").change(function(){
        if ($(this).val() === '1') {
            $('#rowInputPublicKey').addClass('hide');
            $('#InputPublicKey').val("");
            $('#rowInputPassword').removeClass('hide');
            $('#newServerForm')
                    .bootstrapValidator('enableFieldValidators', 'InputPassword', true);
        } else {
            $('#rowInputPassword').addClass('hide');
            $('#InputPassword').val("");
            $('#rowInputPublicKey').removeClass('hide');
            $('#newServerForm')
                    .bootstrapValidator('enableFieldValidators', 'InputPassword', false);
        }
    });

    $("#AdvancedOptions").click(function(){
        $("#rowAdvancedOptions").addClass('hide');
        $("#rowInputPintronPath").fadeIn(800);
        $("#rowInputProxyCommand").fadeIn(800);
        $("#rowInputWorkingDir").fadeIn(800);
        $("#rowInputCallback").fadeIn(800);
        $("#rowInputCallbackURL").fadeIn(800);
    });

    $("#InputCallback").click(function(){
        if($(this).is(":checked")) {
            $('#rowInputCallbackURL').removeClass('hide');
            $('#newServerForm').bootstrapValidator('enableFieldValidators', 'InputCallbackURL', true);
        } else {
            $('#InputCallbackURL').val("");
            $('#rowInputCallbackURL').addClass('hide');
            $('#newServerForm').bootstrapValidator('enableFieldValidators', 'InputCallbackURL', false);
        }
    });




    $("#newServerForm").bootstrapValidator(options);
    var submit = false;
    $("#submitTest").click(function(){
        $("#alertSuccess").fadeOut();
        $("#alertError").fadeOut();
        $("#alertErrorServer").fadeOut();
        $("#newServerForm")
            .bootstrapValidator(options)
            // do this only if bootstrap-validator has success
            .on('success.form.bv', function(e) {
                // override standard submit
                if (submit) {
                    return false;
                }
                $("#alertValidating").fadeIn();
                submit = true;
                e.preventDefault();    //Prevent Default action.
                e.stopPropagation();   //and don't propagate!
                var formObj = $(this);
                var formURL = formObj.attr("action");
                var formData = new FormData(this);
                // send the request via ajax
                var posting = $.ajax({
                    url: '/admin/servers/test',
                    type: 'POST',
                    dataType: 'json',
                    data:  formData,
                    mimeType:"multipart/form-data",
                    contentType: false,
                    cache: false,
                    processData:false,
                    success: function( data ) {
                        // when all works well do...
                        $("#alertValidating").fadeOut(500);
                        if(data.success === true) {
                            $("#alertSuccess").fadeIn(500);
                        } else {
                            $("#errorText").empty().append(data.msg.replace(/(?:\r\n|\r|\n)/g, '<br />'));
                            $("#alertError").fadeIn(500);
                        }
                        $("button[type=server]").removeAttr("disabled");
                        submit = false;
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        // when all works well do...
                        $("#alertValidating").fadeOut(500);
                        $("#alertErrorServer").fadeIn(500);
                        $("button[type=server]").removeAttr("disabled");
                        submit = false;
                    },
                });
                $("#newServerForm").off('success.form.bv');
                return false;
            });
    });

    $("#submitReal").click(function(){
        $("#alertSuccess").fadeOut();
        $("#alertError").fadeOut();
        $("#alertErrorServer").fadeOut();
        $("#newServerForm")
            .bootstrapValidator(options)
            .on('success.form.bv', function(e) {
                if (submit) {
                    return false;
                }
                submit = true;

                document.forms['newServerForm'].submit();
                return false;
            });
    });


});
