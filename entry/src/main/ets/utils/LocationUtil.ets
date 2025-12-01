import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { PERMISSIONS } from '../utils/Constants';

export class LocationUtil {
  async checkLocationPermissions(): Promise<boolean> {
    try {
      for (const permission of PERMISSIONS) {
        const status = await this.checkPermission(permission);
        if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (error) {
      console.error(`Permission check error: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private async checkPermission(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    const atManager = abilityAccessCtrl.createAtManager();
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    const tokenId = bundleInfo.appInfo.accessTokenId;
    return await atManager.checkAccessToken(tokenId, permission);
  }

  async requestLocationPermissions(context: Context): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        context,
        PERMISSIONS
      );

      return result.authResults.every(
        status => status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      );
    } catch (error) {
      console.error(`Permission request error: ${JSON.stringify(error)}`);
      return false;
    }
  }
}

export default new LocationUtil();