<div id='maps'></div>
<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script>
function printMaps(myMap){
  $("#maps").append('<p>&nbsp;</p>');
  $.ajax({
    type: "GET",
    url: myMap+"?request=GetCapabilities&service=wms&version=1.3.0",
    dataType: "xml",
    success: function(xml) {
        $(xml).find('Service').each(function(){
             $("#maps").append('<h1 class="is-size-2">' + $(this).children("Title").text() + '</h1>');
             $("#maps").append('<p>' + $(this).children("Abstract").text() + '</p>');
             $("#maps").append('<p>Access constraints: '+ $(this).children("AccessConstraints").text() +'</p>');
        });
        $("#maps").append('<p>Service: <a href="'+ myMap +'?request=GetCapabilities&service=wms&version=1.3.0">'+ window.location.href + '?request=GetCapabilities&service=wms&version=1.3.0</a></p><p>&nbsp;</p>');
        $("#maps").append("<h2 class='is-size-3'>Layers in this service</h2>");
        $(xml).find('Layer').each(function(){
 				if ($(this).children("Name").text() != '') {
 					myLayer = '<div class="box">'+
                        '<b>' + $(this).children("Title").text() + '</b>'+
                        '<span style="float:right"><a href="' + myMap + '?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=-19948500.0,-6147449.0951699,19688885.757062882,8361000.0&CRS=EPSG:152160&WIDTH=1426&HEIGHT=895&LAYERS='+$(this).children("Name").text()+'&STYLES=&FORMAT=application/openlayers">View</a></span><br/>' +
                        $(this).children("Abstract").text();
                    mdurl = $(this).find('MetadataURL').find('OnlineResource').attr('xlink:href');
                    if (mdurl && mdurl != ''){
                        myLayer += '<br/><a href="'+mdurl+'">Metadata</a>';
                    }
                    myLayer += '</div>';
                    $("#maps").append(myLayer);
 				}
			});
        },
    error: function (xml) {
        $("#maps").append('An error occured while connecting to <a href="'+ myMap +'?request=GetCapabilities&service=wms&version=1.3.0">'+ window.location.href + '?request=GetCapabilities&service=wms&version=1.3.0</a>, the service may be down.');
    }
  });
}
</script>