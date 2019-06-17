window.setupDraggable = function setupDraggable(sendEvent) {
  const BEACON_ATTRIBUTE = "data-beacon";
  const MINIMUM_DRAG_DISTANCE_PX = 10;

  document.addEventListener("pointerdown", awaitDragStart);

  function awaitDragStart(startEvent) {
    document.addEventListener("pointermove", maybeDragMove);
    document.addEventListener("pointerup", stopAwaitingDrag);

    function stopAwaitingDrag() {
      document.removeEventListener("pointermove", maybeDragMove);
      document.removeEventListener("pointerup", stopAwaitingDrag);
    }

    function maybeDragMove(moveEvent) {
      const dragDistance = distance(coords(startEvent), coords(moveEvent));
      if (dragDistance >= MINIMUM_DRAG_DISTANCE_PX) {
        dragEvent("start", startEvent);
        dragEvent("move", moveEvent);
        stopAwaitingDrag();
        document.addEventListener("pointermove", dragMove);
        document.addEventListener("pointerup", dragEnd);
      }
    }
  }

  function dragEnd(event) {
    dragEvent("stop", event);
    document.removeEventListener("pointermove", dragMove);
    document.removeEventListener("pointerup", dragEnd);
  }

  function dragMove(event) {
    dragEvent("move", event);
  }

  function dragEvent(type, event) {
    sendEvent({
      type: type,
      cursor: coords(event),
      beacons: beaconPositions()
    });
  }

  function beaconPositions() {
    const beaconElements = document.querySelectorAll(`[${BEACON_ATTRIBUTE}]`);
    return Array.from(beaconElements).map(beaconData);
  }

  function beaconData(elem) {
    const boundingRect = elem.getBoundingClientRect();
    const beaconId = elem.getAttribute(BEACON_ATTRIBUTE);
    return {
      id: tryParse(beaconId),
      x: boundingRect.x,
      y: boundingRect.y,
      width: boundingRect.width,
      height: boundingRect.height
    };
  }

  function tryParse(str) {
    try {
      return JSON.parse(str);
    } catch (e) {
      return str;
    }
  }

  function coords(event) {
    return { x: event.clientX, y: event.clientY };
  }

  function distance(pos1, pos2) {
    const dx = pos1.x - pos2.x;
    const dy = pos1.y - pos2.y;
    return Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2));
  }
};
