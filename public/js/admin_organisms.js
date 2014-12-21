var options = {
        feedbackIcons: {
            required: 'fa fa-asterisk',
            valid: 'fa fa-check',
            invalid: 'fa fa-times',
            validating: 'fa fa-refresh'
        },
        fields: {
            InputName: {
                validators: {
                    notEmpty: {
                        message: 'The name is required'
                    },
                    stringLength: {
                        min: 2,
                        max: 40,
                        message: 'The full name must be more than 3 and less than 40 characters'
                    }
                }
            },
            InputEnsembl: {
                validators: {
                    notEmpty: {
                        message: 'The ensembl name is required'
                    },
                    stringLength: {
                        min: 2,
                        max: 40,
                        message: 'The full name must be more than 3 and less than 40 characters'
                    }
                }
            }
        }
    };

$(document).ready(function() {
    $("#newOrganismForm").bootstrapValidator(options);
});
