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
            // $('#newJob').bootstrapValidator('addField', $option);
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
            // $('#newJob').bootstrapValidator('addField', $option);
        })

        // Remove button click handler (URL)
        .on('click', '.removeButtonURL', function() {
            var $row    = $(this).parents('.form-group'),
                $option = $row.find('[name="InputURLs[]"]');

            // Remove element containing the option
            $row.remove();

            // Remove field
            // $('#newJob').bootstrapValidator('removeField', $option);
        })

        // Remove button click handler (File)
        .on('click', '.removeButtonFile', function() {
            var $row    = $(this).parents('.form-group'),
                $option = $row.find('[name="InputFiles[]"]');

            // Remove element containing the option
            $row.remove();

            // Remove field
            // $('#newJob').bootstrapValidator('removeField', $option);
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

    // form JS per load dei job in realtime
    _get_jobs();

});

function _get_jobs(){
    $('#letture').append('<li>creo tabella</li>');
    var feedback = $.ajax({
        type: "GET",
        url: "/jobs/update",
        async: false,
        dataType: 'json',
        mimeType:"multipart/form-data",
        contentType: false,
        cache: false,
        processData:false
    }).complete(function( data ){
        _createTable(data.responseText);
        setTimeout(function(){_get_jobs_update();}, 10000);
    }).responseText;
}

function _get_jobs_update(){
    var feedback = $.ajax({
        type: "GET",
        url: "/jobs/update",
        async: false,
        dataType: 'json',
        mimeType:"multipart/form-data",
        contentType: false,
        cache: false,
        processData:false
    }).complete(function( data ){
        _modifyTable(data.responseText);
        setTimeout(function(){_get_jobs_update();}, 10000);
    }).responseText;
}

function _createTable ( i ) {
    var data = JSON.parse(i);
    if (data.success === false) {
        // non ancora gestito
    } else {
        $.each(data.jobs, function(i, item){
            $('#jobsList tr:last').after(
                '<tr class="green hidden-top">' +
                    "<td class='btl'><div id='" + item.id + "_name'>" + _get_name(item.gene_name) + '</div></td>' +
                    '<td class="btr" colspan="3">' +
                        'Description:' + item.description +
                    '</td>' +
                '</tr>' +
                '<tr class="green">' +
                    '<td width="32%" class="centered hidden-bottom">Genomics</td>' +
                    '<td width="32%" class="centered hidden-bottom">Reads</td>' +
                    '<td width="32%" class="centered hidden-bottom">Processing</td>' +
                    '<td width="4%"  class="centered hidden-bottom">Actions</td>' +
                '</tr>' +
                '<tr class="green">' +
                    '<td>' +
                        "<div id='" + item.id + "_genomics_status'>" +
                        _create_alert(item.genomics_ok,
                                      item.genomics_failed,
                                      item.genomics_last_error) +
                        "</div>" +
                    '</td>' +
                    "<td rowspan='3'>" +
                        "<div class='progress hidden-form'>" +
                            "<div id='" + item.id + "_bar'" +
                                "class='progress-bar progress-bar-striped active' " +
                                "role='progressbar' aria-valuenow='" + item.reads_done + "'" +
                                "aria-valuemin='0' aria-valuemax='" + item.reads_total + "'" +
                                "style='width: " + (item.reads_done / item.reads_total * 100) + "%'>" +
                            '</div>' +
                        '</div>' +
                        '<br />' +
                        "<div id='" + item.id + "_reads_status'>" +
                        _create_alert(item.all_reads_ok,
                                      item.some_reads_failed,
                                      item.reads_last_error,
                                      item.reads_done,
                                      item.reads_total) +
                        "</div>" +
                    '</td>' +
                    "<td rowspan='3'></td>" +
                    "<td rowspan='3'class='centered bbr'>" +
                        _create_play_pause(true, item.id) +
                        "<form action='/jobs/delete' method='post'>" +
                            "<input type='hidden' name='job_id' value='" + item.id + "' class='btn'>" +
                            "<button " +
                                "onClick='return confirm('Would you like to delete asd?');'" +
                                "type='submit' class='btn btn-primary' title='delete'>" +
                                "<i class='fa fa-trash-o'></i>" +
                            "</button>" +
                        "</form>" +
                    '</td>' +
                '</tr>' +
                '<tr class="green">' +
                    '<td class="centered hidden-bottom">Ensembl</td>' +
                '</tr>' +
                '<tr class="green">' +
                    '<td class="bbl">' +
                        "<div id='" + item.id + "_ensembl_status'>" +
                        _create_alert(item.ensembl_ok,
                                      item.ensembl_failed,
                                      item.ensembl_last_error) +
                        "</div>" +
                    '</td>' +
                '</tr>' +
                '<tr>' +
                    '<td colspan="4" class="hidden-left hidden-right hidden-bottom hidden-top"></td>' +
                '</tr>'
            );
        });
    }
}

function _modifyTable( i ) {
    var data = JSON.parse(i);
    if (data.success === false) {
        // non ancora gestito
    } else {
        $.each(data.jobs, function(i, item){
            $("#" + item.id + "_name").empty().append(_get_name(item.gene_name));
            $("#" + item.id + "_genomics_status").empty().append(
                _create_alert(item.genomics_ok,
                              item.genomics_failed,
                              item.genomics_last_error)
            );
            $("#" + item.id + "_ensembl_status").empty().append(
                _create_alert(item.ensembl_ok,
                              item.ensembl_failed,
                              item.ensembl_last_error)
            );
            $("#" + item.id + "_reads_status").empty().append(
                _create_alert(item.all_reads_ok,
                              item.some_reads_failed,
                              item.reads_last_error,
                              item.reads_done,
                              item.reads_total)
            );
            $("#" + item.id + "_bar").css("width", ((item.reads_done / item.reads_total * 100) + "%"));
        });
    }
}

function _get_name ( name ) {
    var r = 'Waiting for genomic';
    if (name) {
        r = name;
    }
    return r;
}

function _create_alert (ok, fail, last_error, done, total) {
    var r = '';
    if (ok) {
        r +=    '<div class="alert alert-success hidden-form">' +
                    "<strong><i class='fa fa-check'></i> Data downloaded!</strong>" +
                '</div>';
    } else if (fail) {
        r +=    '<div class="alert alert-danger hidden-form">' +
                    "<strong><i class='fa fa-times'></i> Error: </strong>" + last_error +
                '</div>';
    } else {
        r +=    "<div class='alert alert-info hidden-form'>" +
                    "<i class='fa fa-spinner fa-spin'></i> " +
                    "<strong>Download in progress</strong>";
        if (total) {
            r +=" (" + done + '/' + total + ")";
        }
        r +=        '</div>';
    }
    return r;
}

function _create_play_pause ( running, id ) {
    var r = '';
    if ( running ) {
        r +=   "<form action='/jobs/pause' method='post'>" +
                    "<button type='submit' class='btn btn-primary' title='pause'>" +
                        "<i class='fa fa-pause'></i>" +
                    "</button>" +
                    "<input type='hidden' name='job_id' value=" + id + " class='btn'>" +
                "</form>";
    } else {
        r +=   "<form action='/jobs/restart' method='post'>" +
                    "<button type='submit' class='btn btn-primary' title='restart'>" +
                        "<i class='fa fa-play'></i>" +
                    "</button>" +
                    "<input type='hidden' name='job_id' value=" + id + " class='btn'>" +
                "</form>";
    }
    return r;
}

