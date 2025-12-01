import { map, mapCommon, navi } from '@kit.MapKit';

export class DrawRouteModel {
  async drawRoute(mapController: map.MapComponentController | undefined, steps: Array<navi.RouteRoad>) {
    if (mapController === undefined) {
      console.info('Drawing failed');
      return;
    }
    let roads: Array<mapCommon.LatLng> = [];
    let end: mapCommon.LatLng = {
      latitude: steps[steps.length - 1].endLocation.latitude,
      longitude: steps[steps.length - 1].endLocation.longitude
    };

    for (let index = 0; index < steps.length; index++) {
      for (let i = 0; i < steps[index].polyline.length; i++) {
        roads.push(steps[index].polyline[i]);
      }
    }

    let polylineOption: mapCommon.MapPolylineOptions = {
      points: roads,
      color: 0xFF3498db,
      jointType: mapCommon.JointType.BEVEL,
      startCap: mapCommon.CapStyle.ROUND,
      endCap: mapCommon.CapStyle.ROUND,
      width: 16,
      patterns: [
        {
          type: mapCommon.PatternItemType.DASH,
          length: 16
        },
        {
          type: mapCommon.PatternItemType.GAP,
          length: 16
        }
      ]
    };
    this.addMarker(mapController, end).then(() => {
      mapController.addPolyline(polylineOption).then(() => {
        console.info('Drawing success');
      });
    });
  }

  async addMarker(mapController: map.MapComponentController, position: mapCommon.LatLng) {
    let markerOptions: mapCommon.MarkerOptions = {
      position: position,
      rotation: 0,
      visible: true,
      zIndex: 0,
      alpha: 1,
      anchorU: 0.5,
      anchorV: 1,
      clickable: false,
      draggable: false,
      flat: false
    };
    await mapController.addMarker(markerOptions);
  }
}