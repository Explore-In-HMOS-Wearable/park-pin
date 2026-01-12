import { map, mapCommon, MapComponent, navi } from '@kit.MapKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { curves } from '@kit.ArkUI';
import { DrawRouteModel } from '../viewmodel/DrawRouteModel';
import { preferences } from '@kit.ArkData';
import LocationUtil from '../utils/LocationUtil';

@Entry
@Component
struct Index {
  private mapOptions?: mapCommon.MapOptions;
  private callback?: AsyncCallback<map.MapComponentController>;
  private mapController: map.MapComponentController | undefined;
  private currLocation: geoLocationManager.Location | undefined = undefined;
  @State marker?: map.Marker = undefined
  @State flag: boolean = false
  @State markerTitle: string = ''
  private drawRouteModel: DrawRouteModel = new DrawRouteModel();
  @StorageLink('routes') routes: Array<navi.Route> | undefined = [];
  locationPrefs: preferences.Preferences | null = null;

  aboutToAppear(): void {
    this.initLocationPreferences(this.getUIContext().getHostContext() as common.UIAbilityContext);

    this.mapOptions = {
      position: {
        target: {
          latitude: 41.0082,
          longitude: 28.9784
        },
        zoom: 6
      }
    };

    this.callback = async (err: BusinessError | null, controller: map.MapComponentController) => {
      if (err) {
        console.error(` Map initialization failed: ${JSON.stringify(err)}`);
        return;
      }

      this.mapController = controller;
      console.info(`Map initialized successfully`);

      controller.on('mapLoad', async () => {
        console.info(` Map loaded`);
        await this.handleLocationPermissions();
        this.registerMarkerClickEvent()
        this.onMarkerDragEvent()

        if (this.locationPrefs && this.locationPrefs.hasSync('park_lat') && this.locationPrefs.hasSync('park_lng') &&
        this.locationPrefs.hasSync('park_title')) {
          const lat = this.locationPrefs.getSync('park_lat', 0);
          const lng = this.locationPrefs.getSync('park_lng', 0);
          const title = this.locationPrefs.getSync('park_title', '');

          const markerOptions: mapCommon.MarkerOptions = {
            position: {
              latitude: Number(lat),
              longitude: Number(lng)
            },
            visible: true,
            clickable: true,
            draggable: true
          };

          this.marker = await controller.addMarker(markerOptions);
          this.marker.setDraggable(true);
          this.marker.setClickable(true);
          this.marker.setTitle(title.toString());
          this.marker.setInfoWindowVisible(true);
        }
      });
    };
  }

  async drawRouteToMarker(marker: map.Marker): Promise<void> {
    if (!this.currLocation) {
      console.error(` Current location not available`);
      return;
    }

    try {
      const markerPosition = marker.getPosition();
      let params: navi.RouteParams = {
        origins: [{
          'latitude': this.currLocation.latitude,
          'longitude': this.currLocation.longitude
        }],
        destination: {
          'latitude': markerPosition.latitude,
          'longitude': markerPosition.longitude
        }
      };
      console.info(` Getting route from current location to marker...`);
      const result = await navi.getWalkingRoutes(params);
      console.info(` Succeeded in getting driving routes`);
      if (result.routes !== undefined && result.routes.length > 0 && this.mapController) {
        this.mapController.clear();

        await this.drawRouteModel.drawRoute(this.mapController, result.routes[0].steps[0].roads)
          .then(() => {
            console.info(` Route drawn successfully`);
          });
      } else {
        console.warn(` No routes found`);
      }
    } catch (error) {
      console.error(` Error drawing route: ${JSON.stringify(error)}`);
    }
  }

  private registerMarkerClickEvent(): void {
    if (this.mapController) {
      this.mapController.on('markerClick', (marker) => {
        console.info('markerClick', `on-markerClick position = ${marker.getId()}`);
        this.drawRouteToMarker(marker);
      });
    }
  }

  private onMarkerDragEvent(): void {
    if (this.mapController) {
      this.mapController.on('markerDrag', (marker) => {
        let position = marker.getPosition()
        console.info('markerDrag', `on-markerDrag position = ${marker.getId()}`);

        if (this.locationPrefs) {
          this.locationPrefs.putSync('park_lat', position.latitude);
          this.locationPrefs.putSync('park_lng', position.longitude);
          this.locationPrefs.flush((err) => {
            if (err) {
              console.error(`Flush error:', ${JSON.stringify(err)}`);
            } else {
            }
          });
        }
      });
    }
  }

  async handleLocationPermissions(): Promise<void> {
    try {
      const hasPermissions = await LocationUtil.checkLocationPermissions()

      if (hasPermissions) {
        await this.showUserLocation();
      } else {
        const granted = await LocationUtil.requestLocationPermissions(this.getUIContext()
          .getHostContext() as common.UIAbilityContext);
        if (granted) {
          await this.showUserLocation();
        }
      }
    } catch (error) {
      console.error(`Error handling permissions: ${JSON.stringify(error)}`);
    }
  }

  async showUserLocation(): Promise<void> {
    if (!this.mapController) {
      console.error(` Map controller not initialized`);
      return;
    }

    try {
      this.mapController.setMyLocationEnabled(true);
      this.mapController.setMyLocationControlsEnabled(true);

      let request: geoLocationManager.SingleLocationRequest =
        { 'locatingTimeoutMs': 1000, 'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED };

      geoLocationManager.getCurrentLocation(request)
        .then((result) => {
          if (result) {
            if (this.mapController) {
              console.info(` tag current location:  ${JSON.stringify(result)}`);
              this.mapController.setMyLocation(result);
              this.currLocation = result
            }
          }
        })
        .catch((error: BusinessError) => {
          console.error(`tag promise, getCurrentLocation: error=' + ${JSON.stringify(error)}`);
        });

      if (this.currLocation) {
        console.info(` Current location: ${JSON.stringify(this.currLocation)}`);

        let cameraPosition: mapCommon.CameraPosition = {
          target: this.currLocation,
          zoom: 16
        };

        let cameraUpdate: map.CameraUpdate = map.newCameraPosition(cameraPosition);
        this.mapController.moveCamera(cameraUpdate);
      }
    } catch (error) {
      console.error(` Error getting location: ${JSON.stringify(error)}`);
      this.mapController.animateCamera({
        center: {
          latitude: this.mapOptions?.position.target.latitude,
          longitude: this.mapOptions?.position.target.longitude
        },
        zoom: 18
      });
    }
  }

  async addMarker() {
    if (this.currLocation) {
      let markerOptions: mapCommon.MarkerOptions = {
        position: {
          latitude: this.currLocation.latitude,
          longitude: this.currLocation.longitude
        },
        visible: true,
        clickable: true,
        draggable: true,
        flat: false
      };

      if (this.mapController) {
        this.marker = await this.mapController.addMarker(markerOptions);
        this.marker.setDraggable(true);
        this.marker.setTitle(this.markerTitle);
        this.marker.setClickable(true);
        this.marker.setInfoWindowVisible(true);
        const markerPosition = this.marker.getPosition();

        if (this.locationPrefs) {
          this.locationPrefs.putSync('park_lat', markerPosition.latitude);
          this.locationPrefs.putSync('park_lng', markerPosition.longitude);
          this.locationPrefs.putSync('park_title', this.markerTitle);
          this.locationPrefs.flush((err) => {
            if (err) {
              console.error('Flush error:', JSON.stringify(err));
            } else {
            }
          });
        }
      }
    }
  }

  onPageShow(): void {
    this.mapController?.show();
  }

  onPageHide(): void {
    this.mapController?.hide();
  }

  @Builder
  AddMarkerDialog() {
    Column({ space: 10 }) {

      Text($r('app.string.marker_info'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
        .width('100%')
        .textAlign(TextAlign.Center)

      Blank()

      Row({ space: 6 }) {
        Text($r('app.string.dialog_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Regular)
          .fontColor(Color.Black)
          .textAlign(TextAlign.Start)

        Blank()

        TextInput({ placeholder: $r('app.string.dialog_title_placeholder') })
          .onChange((value: string) => this.markerTitle = value)
          .width('60%')
          .fontSize(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .borderWidth(1)
          .borderColor(Color.Black)
          .fontColor(Color.Black)
      }
      .margin({ left: 4, right: 4 })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceEvenly)
      .width('90%')

      Button($r('app.string.add_marker'))
        .borderRadius(18)
        .height(50)
        .enabled(this.markerTitle.trim().length > 0)
        .onClick(() => {
          this.flag = false
          this.addMarker()
        })
    }
    .padding(40)
    .rotate({ angle: 0 })
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  build() {
    Column() {
      Stack() {
        MapComponent({
          mapOptions: this.mapOptions,
          mapCallback: this.callback,
          customInfoWindow: this.customInfoWindow
        })
          .width('100%')
          .height('100%')
          .onClick(() => {
            console.info(` Map clicked`);
          })
          .zIndex(1)

        Column({ space: 6 }) {
          Text($r('app.string.marker'))
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.Black)
            .fontSize(12)

          Image($r('app.media.ic_add'))
            .height(20)
            .width(20)
            .onClick(() => {
              this.flag = true
            })
            .bindContentCover($$this.flag, this.AddMarkerDialog(), {
              transition: TransitionEffect.translate({ y: 1000 }).animation({ curve: curves.springMotion(0.6, 0.8) })
            })

          Image($r('app.media.ic_delete'))
            .height(20)
            .width(20)
            .onClick(() => {
              this.mapController?.clear()

              if (this.locationPrefs) {
                this.locationPrefs.deleteSync('park_lat');
                this.locationPrefs.deleteSync('park_lng');
                this.locationPrefs.flush((err) => {
                  if (err) {
                    console.error('Flush error during delete:', JSON.stringify(err));
                  } else {
                  }
                });
              }
            })
        }
        .padding(4)
        .position({ x: '12%', y: '50%' })
        .backgroundColor(Color.White)
        .borderRadius(18)
        .borderColor(Color.Black)
        .borderWidth(1)
        .zIndex(2)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @BuilderParam customInfoWindow: ($$: map.MarkerDelegate) => void = this.customInfoWindowBuilder;

  @Builder
  customInfoWindowBuilder($$: map.MarkerDelegate) {
    if ($$.marker) {
      Column({ space: 6 }) {
        Text($$.marker.getTitle())
          .width('50%')
          .textAlign(TextAlign.Center)
          .fontColor(Color.Black)
          .fontSize(16)
      }
      .backgroundColor(Color.Orange)
      .opacity(0.6)
      .borderRadius(16)
      .borderWidth(1)
      .borderColor(Color.Orange)
    }
  }

  async initLocationPreferences(context: common.UIAbilityContext) {
    const options: preferences.Options = { name: 'location_store' };
    this.locationPrefs = preferences.getPreferencesSync(context, options);
  }
}