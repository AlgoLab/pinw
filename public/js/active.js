$(document).ready(function() {
    // The maximum number of options
    var MAX_OPTIONS_URLS = 5;
    var MAX_OPTIONS_FILES = 5;

    $('#newJob')

        // Add button click handler (URL)
        .on('click', '.addButtonURL', function() {
            var $template = $('#InputURLTemplate'),
                $clone    = $template
                                .clone()
                                .removeClass('hide')
                                .removeAttr('id')
                                .insertBefore($template),
                $option   = $clone.find('[name="InputURLs[]"]');

            // Add new field
            $('#newJob').bootstrapValidator('addField', $option);
        })

        // Add button click handler (File)
        .on('click', '.addButtonFile', function() {
            var $template = $('#InputFileTemplate'),
                $clone    = $template
                                .clone()
                                .removeClass('hide')
                                .removeAttr('id')
                                .insertBefore($template),
                $option   = $clone.find('[name="InputFiles[]"]');

            // Add new field
            $('#newJob').bootstrapValidator('addField', $option);
        })

        // Remove button click handler (URL)
        .on('click', '.removeButtonURL', function() {
            var $row    = $(this).parents('.form-group'),
                $option = $row.find('[name="InputURLs[]"]');

            // Remove element containing the option
            $row.remove();

            // Remove field
            $('#newJob').bootstrapValidator('removeField', $option);
        })

        // Remove button click handler (File)
        .on('click', '.removeButtonFile', function() {
            var $row    = $(this).parents('.form-group'),
                $option = $row.find('[name="InputFiles[]"]');

            // Remove element containing the option
            $row.remove();

            // Remove field
            $('#newJob').bootstrapValidator('removeField', $option);
        })

        // Called after adding new field
        .on('added.field.bv', function(e, data) {
            // data.field   --> The field name
            // data.element --> The new field element
            // data.options --> The new field options

            if (data.field === 'InputURLs[]') {
                if ($('#newJob').find(':visible[name="InputURLs[]"]').length >= MAX_OPTIONS_URLS) {
                    $('#newJob').find('.addButtonURL').attr('disabled', 'disabled');
                }
            }

            if (data.field === 'InputFiles[]') {
                if ($('#newJob').find(':visible[name="InputFiles[]"]').length >= MAX_OPTIONS_FILES) {
                    $('#newJob').find('.addButtonFile').attr('disabled', 'disabled');
                }
            }
        })

        // Called after removing the field
        .on('removed.field.bv', function(e, data) {
            if (data.field === 'InputURLs[]') {
                if ($('#newJob').find(':visible[name="InputURLs[]"]').length < MAX_OPTIONS_URLS) {
                    $('#newJob').find('.addButtonURL').removeAttr('disabled');
                }
            }

            if (data.field === 'InputFiles[]') {
                if ($('#newJob').find(':visible[name="InputFiles[]"]').length < MAX_OPTIONS_FILES) {
                    $('#newJob').find('.addButtonFile').removeAttr('disabled');
                }
            }
        })

        .on('shown.bs.modal', function (e) {
            $("#InputQuality").slider();
        });

    // select the source of input data

    $("input[name='type']").change(function(){
        if ($(this).val() === '1') {
            $('#rowInputGeneURL').addClass('hide');
            $('#InputGeneURL').val("");
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').val("");
            $('#rowInputGeneName').removeClass('hide');
            $('#newJob')
                    .bootstrapValidator('enableFieldValidators', 'InputGeneName', true)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneURL', false)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneFile', false);
        } else if ($(this).val() === '2') {
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').val("");
            $('#rowInputGeneName').addClass('hide');
            $('#InputGeneName').val("");
            $('#rowInputGeneURL').removeClass('hide');
            $('#newJob')
                    .bootstrapValidator('enableFieldValidators', 'InputGeneURL', true)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneName', false)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneFile', false);
        } else {
            $('#rowInputGeneURL').addClass('hide');
            $('#InputGeneURL').val("");
            $('#rowInputGeneName').addClass('hide');
            $('#InputGeneName').val("");
            $('#rowInputGeneFile').removeClass('hide');
            $('#newJob')
                    .bootstrapValidator('enableFieldValidators', 'InputGeneFile', true)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneName', false)
                    .bootstrapValidator('enableFieldValidators', 'InputGeneURL', false);
        }
    });

    $("[data-toggle=tooltip]").tooltip();
    $('#newJob').bootstrapValidator({
        feedbackIcons:{
            valid: 'glyphicon glyphicon-ok',
            invalid: 'glyphicon glyphicon-remove',
            validating: 'glyphicon glyphicon-refresh'
        },
        fields: {
            InputGeneName: {
                validators: {
                    notEmpty: {
                        message: 'The date is required and cannot be empty'
                    }
                }
            },
            InputGeneURL: {
                enabled: false,
                validators: {
                    notEmpty: {
                        message: 'The date is required and cannot be empty'
                    }
                }
            },
            InputGeneFile: {
                enabled: false,
                validators: {
                    notEmpty: {
                        message: 'The date is required and cannot be empty'
                    }
                }
            }
        }
    });
});