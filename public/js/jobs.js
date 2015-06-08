var previous_job_list = [];
var actual_job_list = [];

$(document).ready(function() {
    // The maximum number of options
    var MAX_OPTIONS_URLS = 5;
    var MAX_OPTIONS_FILES = 5;
    var querystring = _querystring('auto');

    if (querystring.length) {
        $('#newJob').modal('show');
    }

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
            $("#InputQuality").on("slide", function(slideEvt) {
                $("#QualityTs").text(slideEvt.value);
            });
        });

    // organism block
    $('#Organism').change(function(){
        if ($(this).is(':checked')) {
            $('#InputOrganism').prop('disabled', 'disabled');
            $('#InputOrganism').val('');
            $('#InputOrganism').removeAttr('required');
            $('#downloadEnsembl').prop('disabled', 'disabled');
            $('#downloadEnsembl').prop('checked', false);
            $('#downloadFastaURL').prop('checked', true);
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').removeAttr('required');
            $('#InputGeneFile').val("");
            $('#InputGeneURL').prop('required', true);
            $('#rowInputGeneURL').removeClass('hide');
            $('#InputTranscripts').prop('disabled', 'disabled');
            $('#InputTranscripts').prop('checked', false);
        } else {
            $('#InputOrganism').prop('disabled', false);
            $('#InputOrganism').attr('required', true);
            if ( !$('#GeneName').is(':checked')) {
                $('#downloadEnsembl').prop('disabled', false);
                $('#InputTranscripts').prop('disabled', false);
            }
        }
    });


    // gene name block
    $('#GeneName').change(function(){
        if ($(this).is(':checked')) {
            $('#InputGeneName').prop('disabled', 'disabled');
            $('#InputGeneName').val('');
            $('#InputGeneName').removeAttr('required');
            $('#downloadEnsembl').prop('disabled', 'disabled');
            $('#downloadEnsembl').prop('checked', false);
            $('#downloadFastaURL').prop('checked', true);
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').removeAttr('required');
            $('#InputGeneFile').val("");
            $('#InputGeneURL').prop('required', true);
            $('#rowInputGeneURL').removeClass('hide');
            $('#InputTranscripts').prop('disabled', 'disabled');
            $('#InputTranscripts').prop('checked', false);
        } else {
            $('#InputGeneName').prop('disabled', false);
            $('#InputGeneName').attr('required', true);
            if ( !$('#Organism').is(':checked')) {
                $('#downloadEnsembl').prop('disabled', false);
                $('#InputTranscripts').prop('disabled', false);
            }
        }
    });

    // genomics block
    $("input[name='type']").change(function(){
        if ($(this).val() === '1') {
            $('#rowInputGeneURL').addClass('hide');
            $('#InputGeneURL').val("");
            $('#InputGeneURL').removeAttr('required');
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').val("");
            $('#InputGeneFile').removeAttr('required');
            $('#rowInputGeneName').removeClass('hide');
        } else if ($(this).val() === '2') {
            $('#rowInputGeneFile').addClass('hide');
            $('#InputGeneFile').removeAttr('required');
            $('#InputGeneFile').val("");
            $('#InputGeneURL').prop('required', true);
            $('#rowInputGeneURL').removeClass('hide');
        } else if ($(this).val() === '3'){
            $('#rowInputGeneURL').addClass('hide');
            $('#InputGeneURL').removeAttr('required');
            $('#InputGeneURL').val("");
            $('#InputGeneFile').prop('required', true);
            $('#rowInputGeneFile').removeClass('hide');
        }
    });
 

    // reads block
    $("#firstReadFile").change(function(){
        if ( $(this).val() ) {
            $('#firstReadURL').removeAttr('required');
        } else {
            $('#firstReadURL').prop('required', true);
        }
    });

    // form JS  (jobs load in realtime)
    _get_jobs();

    // confirm after delete
    $(".delete").click(function(){
        var res = confirm('Do you really want to delete the job?');
        if ( !res ) {
            return false;
        }
    });

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
        _modify_table(data.responseText);
        setTimeout(function(){_get_jobs_update();}, 10000);
    }).responseText;
}

function _createTable ( i ) {
    var data = JSON.parse(i);
    if (data.success === false) {
        // non ancora gestito
    } else {
        $.each(data.jobs, function(i, item){
            previous_job_list.push(item.id);
            $('#jobsList br:last').after(
                "<div class='anchor' id='job_" + item.id +"'></div>" +
                "<div class='panel panel-default panel-primary result'>" +
                    "<div class='panel-heading'>" +
                        "<div id='" + item.id + "_name'>" +
                        _get_name(item.organism.name, item.gene_name, item.id) +
                        (item.paused ? ' (PAUSED) ' : ' ') +
                        (data.admin_view ? 'Owner: ' + item.owner : '') +
                        '</div>' +
                    "</div>" +
                    "<div class='panel-body reduce-padding'>" +
                                (item.description ? ' Description:' + item.description : '') +
                    "</div>" +
                    "<table class='table table-condensed table-result hidden-border'>" +
                        "<tr class='" + item.id + "_tr'>" +
                            "<td colspan='3' >" +
                                "<div>" +
                                    "<ul class='progressbar'>" +
                                        "<li class='down active' id='" + item.id +"_download'>Download</li>" +
                                        "<li class='wait' id='" + item.id +"_waiting'>Awaiting dispatch</li>" +
                                        "<li class='disp' id='" + item.id +"_dispatch'>Dispatch</li>" +
                                        "<li class='proc' id='" + item.id +"_processing' >Processing</li>" +
                                    "</ul>" +
                                "</div>" +
                                "<div id='" + item.id +"_error' class='alert alert-danger hidden-form nascosto'>" +
                                    "<strong><i class='fa fa-times'></i> Error: </strong>" +
                                    (item.processing_error ? item.processing_error : item.dispatch_error) +
                                "</div>" +
                            '</td>' +
                            "<td class='centered'>" +
                                _create_play_pause(item.paused, item.id) +
                                "<form action='jobs/delete' method='post' >" +
                                    "<input type='hidden' name='job_id' value='" + item.id + "' class='btn'>" +
                                    "<button " +
                                        "type='submit' class='btn btn-primary delete' title='delete'>" +
                                        "<i class='fa fa-trash-o'></i>" +
                                    "</button>" +
                                "</form>" +
                            '</td>' +
                        '</tr>' +
                        "<tr class='" + item.id + "_tr' id='" + item.id + "_tr_down_name'>" +
                            '<td width="32%"class="centered hidden-bottom">Genomics</td>' +
                            '<td width="32%" class="centered hidden-bottom">Ensembl</td>' +
                            '<td width="32%" class="centered hidden-bottom">Reads (QT: ' + item.quality_threshold + ') </td>' +
                            
                        '</tr>' +
                        "<tr class='" + item.id + "_tr' id='" + item.id + "_tr_down_box'>" +
                            '<td>' +
                                "<div id='" + item.id + "_genomics_status' class='minibox'>" +
                                _create_alert(item.genomics_ok,
                                              item.genomics_failed,
                                              item.genomics_last_error) +
                                "</div>" +
                            '</td>' +
                            "<td>" +
                                "<div id='" + item.id + "_ensembl_status' class='minibox'>" +
                                (item.ensembl_disabled ? "" +
                                    '<div class="alert alert-success hidden-form">' +
                                        "<strong><i class='fa fa-check'></i> No download requested!</strong>" +
                                    '</div>' :
                                _create_alert(item.ensembl_ok,
                                              item.ensembl_failed,
                                              item.ensembl_last_error)) +
                                "</div>" +
                            '</td>' +
                            "<td>" +
                                "<div id='" + item.id + "_reads_status' class='minibox'>" +
                                _create_alert(item.all_reads_ok,
                                              item.some_reads_failed,
                                              item.reads_last_error,
                                              item.reads_done,
                                              item.reads_total) +
                                "</div>" +
                            '</td>' +
                            
                        '</tr>' +
                    "</table>" +
                "</div>" +
                "<br />"
            );
            _if_download_hide_indicators(item, 0);
            _update_status(item);
            _update_error(item);
        });
    }
}

function _modify_table( i ) {
    var data = JSON.parse(i);
    if (data.success === false) {
        // non ancora gestito
    } else {
        $.each(data.jobs, function(i, item){
            actual_job_list.push(item.id);
            $("#" + item.id + "_name").empty().append('' +
                _get_name(item.organism.name, item.gene_name, item.id) +
                (item.paused ? ' (PAUSED) ' : '')+
                (data.admin_view ? 'Owner: ' + item.owner : ''));
            $("#" + item.id + "_genomics_status").empty().append(
                _create_alert(item.genomics_ok,
                              item.genomics_failed,
                              item.genomics_last_error)
            );
            if ( !item.ensembl_disabled) {
                $("#" + item.id + "_ensembl_status").empty().append(
                    _create_alert(item.ensembl_ok,
                                  item.ensembl_failed,
                                  item.ensembl_last_error)
                );
            }
            $("#" + item.id + "_reads_status").empty().append(
                _create_alert(item.all_reads_ok,
                              item.some_reads_failed,
                              item.reads_last_error,
                              item.reads_done,
                              item.reads_total)
            );
            $("#" + item.id + "_error").empty().append(
                "<strong><i class='fa fa-times'></i> Error: </strong>" +
                (item.processing_error ? item.processing_error : item.dispatch_error)
            );
            _if_download_hide_indicators(item, 500);
            _update_status(item);
            _update_error(item);
        });


        $.each(previous_job_list, function(i, job){
            if ( $.inArray(job, actual_job_list) == -1) {
                $("." + job + "_tr").fadeOut(500, function(){$(this).remove();});
            }
        });
        previous_job_list = actual_job_list;
        actual_job_list = [];
    }
}

function _update_error(item) {
    if (item.dispatch_error || item.processing_error) {
        $("#" + item.id + "_error").fadeIn(500);
    } else {
        $("#" + item.id + "_error").fadeOut(500);
    }
}

function _update_status(item) {
    if (item.processing) {
        $("#" + item.id + "_waiting").addClass("active");
        $("#" + item.id + "_dispatch").addClass("active");
        $("#" + item.id + "_processing").addClass("active");
    } else if (item.dispatching) {
        $("#" + item.id + "_waiting").addClass("active");
        $("#" + item.id + "_dispatch").addClass("active");
    } else if (item.awaiting_dispatch) {
        $("#" + item.id + "_waiting").addClass("active");
    }
}

function _if_download_hide_indicators (item, delay) {
    if (item.genomics_ok && item.ensembl_ok && item.all_reads_ok) {
        $("#" + item.id + "_tr_down_name").fadeOut(delay);
        $("#" + item.id + "_tr_down_box").fadeOut(delay);
    }
}

function _get_name ( organism, gene, id ) {
    var r = " &nbsp; &nbsp;<i class='fa fa-cube'></i> <strong>JOB #" + id;
    if (organism && gene) {
        r += " | " + organism.toUpperCase() + ":" + gene.toUpperCase();
    } else if (organism) {
        r += " | " + organism.toUpperCase();
    } else if (gene) {
        r += " | " + gene.toUpperCase();
    }
    r += '</strong>';
    return r;
}

function _create_alert (ok, fail, last_error, done, total) {
    var r = '';
    if (ok) {
        r +=    '<div class="alert alert-success hidden-form">' +
                    "<strong><i class='fa fa-check'></i> Done!</strong>" +
                '</div>';
    } else if (fail) {
        r +=    '<div class="alert alert-danger hidden-form">' +
                    "<strong><i class='fa fa-times'></i> Error: </strong>" + last_error +
                '</div>';
    } else {
        r +=    "<div class='alert alert-info hidden-form'>" +
                    "<i class='fa fa-spinner fa-spin'></i> " +
                    "<strong>In progress</strong>";
        if (total) {
            r +=" (" + done + '/' + total + ")";
        }
        r +=        '</div>';
    }
    return r;
}

function _create_play_pause ( paused, id ) {
    var r = '';
    if ( paused ) {
        r +=   "<form action='/jobs/resume' method='post'>" +
                    "<button type='submit' class='btn btn-primary' title='restart'>" +
                        "<i class='fa fa-play'></i>" +
                    "</button>" +
                    "<input type='hidden' name='job_id' value=" + id + " class='btn'>" +
                "</form>";
    } else {
        r +=   "<form action='/jobs/pause' method='post'>" +
                    "<button type='submit' class='btn btn-primary' title='pause'>" +
                        "<i class='fa fa-pause'></i>" +
                    "</button>" +
                    "<input type='hidden' name='job_id' value=" + id + " class='btn'>" +
                "</form>";
    }
    return r;
}

// funzione per autoshow del modale

function _querystring(key) {
  var re=new RegExp('(?:\\?|&)'+key+'=(.*?)(?=&|$)','gi');
  var r=[], m;
  while ((m=re.exec(document.location.search)) !== null) r.push(m[1]);
  return r;
}
