//This tells Acrobat to disable the default 3D object selection behaviour.
runtime.overrideSelection = true;

//------------------------------------------------------------------------------
//This will be called when a MouseUp event fires
//------------------------------------------------------------------------------
var myMouseHandlingFunction = function( event ) {
    if ( event.isMouseUp ) {
	var clickedMesh = null;

	//The Hits array actually contains every object that is intersected by
	//a ray from the Camera in the direction of the mouse click.
	//We want the first one; the one closest to the camera.
	if(event.hits.length > 0)
	    clickedMesh = event.hits[0].target;
	
	if(clickedMesh != null) {
	    var str = clickedMesh.name;
	    var bits = str.split('.');
	    host.getField("objectlabel").value = bits[0];
	} else {
	    host.getField("objectlabel").value = "";
	}
    }
} //---------------------------------------------------

//Create the Mouse event handler and set it up to capture mouse up events only
var mouseEventHandler = new MouseEventHandler();
mouseEventHandler.onMouseDown = false;
mouseEventHandler.onMouseMove = false;
mouseEventHandler.onMouseUp = true;
// Note: not a function call, but a reference to a function
mouseEventHandler.onEvent = myMouseHandlingFunction;
runtime.addEventHandler( mouseEventHandler );