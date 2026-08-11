import {
	AmbientLight,
	DirectionalLight,
	MathUtils,
	Mesh,
	MeshStandardMaterial,
	PerspectiveCamera,
	Scene,
	Spherical,
	Vector3,
	WebGLRenderer,
} from 'three';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

export interface PrintController {
	rotate(horizontal: number, vertical?: number): void;
	zoom(amount: number): void;
	reset(): void;
}

export async function renderPrint(
	stage: HTMLElement,
	canvas: HTMLCanvasElement,
	src: string,
): Promise<PrintController> {
	const scene = new Scene();
	const camera = new PerspectiveCamera(40, 1, 0.1, 10000);
	const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true });
	renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

	scene.add(new AmbientLight(0xffffff, 0.65));
	const keyLight = new DirectionalLight(0xffffff, 1.1);
	keyLight.position.set(1, 1.5, 1);
	scene.add(keyLight);
	const fillLight = new DirectionalLight(0xffffff, 0.4);
	fillLight.position.set(-1, -0.5, -1);
	scene.add(fillLight);

	const loader = new STLLoader();
	const geometry = await loader.loadAsync(src);
	geometry.computeVertexNormals();
	geometry.computeBoundingBox();

	const material = new MeshStandardMaterial({ color: 0x9fb4c7, roughness: 0.55, metalness: 0.05 });
	const mesh = new Mesh(geometry, material);

	const box = geometry.boundingBox!;
	const center = box.getCenter(new Vector3());
	const size = box.getSize(new Vector3());
	const radius = Math.max(size.x, size.y, size.z) / 2 || 1;

	mesh.position.sub(center);
	scene.add(mesh);

	camera.position.set(radius * 1.8, radius * 1.4, radius * 2.2);
	camera.near = radius / 100;
	camera.far = radius * 100;
	camera.updateProjectionMatrix();

	const controls = new OrbitControls(camera, canvas);
	canvas.style.touchAction = 'pan-y';
	controls.target.set(0, 0, 0);
	controls.enableDamping = true;
	controls.dampingFactor = 0.08;
	controls.minDistance = radius * 0.5;
	controls.maxDistance = radius * 8;
	controls.update();
	controls.saveState();

	function resize() {
		const rect = stage.getBoundingClientRect();
		const width = Math.max(1, Math.floor(rect.width));
		const height = Math.max(1, Math.floor(rect.height));
		renderer.setSize(width, height, false);
		camera.aspect = width / height;
		camera.updateProjectionMatrix();
	}

	const resizeObserver = new ResizeObserver(resize);
	resizeObserver.observe(stage);
	resize();

	let stageVisible = !('IntersectionObserver' in window);
	let documentVisible = document.visibilityState === 'visible';
	let animationFrame: number | undefined;

	function shouldAnimate() {
		return stageVisible && documentVisible;
	}

	function animate() {
		animationFrame = undefined;
		if (!shouldAnimate()) return;
		controls.update();
		renderer.render(scene, camera);
		animationFrame = requestAnimationFrame(animate);
	}

	function syncAnimation() {
		const active = shouldAnimate();
		stage.dataset.animationState = active ? 'running' : 'paused';

		if (active && animationFrame === undefined) {
			animationFrame = requestAnimationFrame(animate);
		} else if (!active && animationFrame !== undefined) {
			cancelAnimationFrame(animationFrame);
			animationFrame = undefined;
		}
	}

	if ('IntersectionObserver' in window) {
		const visibilityObserver = new IntersectionObserver(
			([entry]) => {
				stageVisible = entry?.isIntersecting ?? false;
				syncAnimation();
			},
			{ threshold: 0.01 },
		);
		visibilityObserver.observe(stage);
	}

	document.addEventListener('visibilitychange', () => {
		documentVisible = document.visibilityState === 'visible';
		syncAnimation();
	});

	const spherical = new Spherical();
	const offset = new Vector3();

	function updateCamera() {
		controls.update();
		if (shouldAnimate()) renderer.render(scene, camera);
		syncAnimation();
	}

	function rotate(horizontal: number, vertical = 0) {
		offset.copy(camera.position).sub(controls.target);
		spherical.setFromVector3(offset);
		spherical.theta += horizontal;
		spherical.phi = MathUtils.clamp(spherical.phi + vertical, 0.1, Math.PI - 0.1);
		offset.setFromSpherical(spherical);
		camera.position.copy(controls.target).add(offset);
		camera.lookAt(controls.target);
		updateCamera();
	}

	function zoom(amount: number) {
		offset.copy(camera.position).sub(controls.target);
		const distance = MathUtils.clamp(
			offset.length() * Math.exp(-amount),
			controls.minDistance,
			controls.maxDistance,
		);
		camera.position.copy(controls.target).add(offset.setLength(distance));
		updateCamera();
	}

	function reset() {
		controls.reset();
		updateCamera();
	}

	syncAnimation();

	return { rotate, zoom, reset };
}
