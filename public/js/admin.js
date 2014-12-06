$(document).ready(function() {
    $('#update').click(function(){
        $('#choose').fadeOut(0);
        $('#select').fadeIn(500);
        $('.formUpdate').fadeIn(500);
    });

    $('#updateModal').on('hidden.bs.modal', function (){
        $('.formUpdate').fadeOut();
        $('#select').fadeOut();
        $('#choose').fadeIn();
    });

    $("#InputDate").datetimepicker({
        dateFormat: 'dd/m/yy',
        timeFormat: 'HH:mm',
        timeText: 'At:',
        hourText: 'Hours',
        minuteText: 'Minute',
        currentText: 'Now',
        closeText: 'Ok',
        defaultTimezone: '+0100',
        minDate: new Date()
    });
});
