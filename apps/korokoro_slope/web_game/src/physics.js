// cannon-es のワールド・マテリアル・ボディ生成まわりのヘルパー。
import * as CANNON from 'cannon-es';

export const BALL_RADIUS = 0.4;

export function createWorld() {
  const world = new CANNON.World({ gravity: new CANNON.Vec3(0, -18, 0) });
  world.broadphase = new CANNON.SAPBroadphase(world);
  world.allowSleep = false;
  world.defaultContactMaterial.friction = 0.4;
  return world;
}

export function createMaterials(world) {
  const ballMaterial = new CANNON.Material('ball');
  const groundMaterial = new CANNON.Material('ground');
  const contact = new CANNON.ContactMaterial(ballMaterial, groundMaterial, {
    friction: 0.55,
    restitution: 0.2,
    contactEquationStiffness: 1e8,
    contactEquationRelaxation: 3,
  });
  world.addContactMaterial(contact);
  return { ballMaterial, groundMaterial };
}

export function createBallBody(material, position) {
  const shape = new CANNON.Sphere(BALL_RADIUS);
  const body = new CANNON.Body({
    mass: 1,
    shape,
    material,
    linearDamping: 0.15,
    angularDamping: 0.2,
  });
  body.position.set(position.x, position.y, position.z);
  return body;
}

/**
 * @param {{material: CANNON.Material, halfExtents: {x:number,y:number,z:number}, position: {x:number,y:number,z:number}, quaternion?: {x:number,y:number,z:number,w:number}, kinematic?: boolean}} opts
 */
export function createPlatformBody(opts) {
  const { material, halfExtents, position, quaternion, kinematic = false } = opts;
  const shape = new CANNON.Box(new CANNON.Vec3(halfExtents.x, halfExtents.y, halfExtents.z));
  const body = new CANNON.Body({
    mass: 0,
    shape,
    material,
    type: kinematic ? CANNON.Body.KINEMATIC : CANNON.Body.STATIC,
  });
  body.position.set(position.x, position.y, position.z);
  if (quaternion) {
    body.quaternion.set(quaternion.x, quaternion.y, quaternion.z, quaternion.w);
  }
  return body;
}

/**
 * ボール直下にレイを飛ばし、コース面の高さを取得する。
 * 見つからなければ null（＝コース外＝転落中）。
 */
export function raycastGround(world, fromPos, maxDistance = 40) {
  const from = new CANNON.Vec3(fromPos.x, fromPos.y + 2, fromPos.z);
  const to = new CANNON.Vec3(fromPos.x, fromPos.y - maxDistance, fromPos.z);
  const result = new CANNON.RaycastResult();
  world.raycastClosest(from, to, {}, result);
  if (!result.hasHit) return null;
  return result.hitPointWorld.y;
}
