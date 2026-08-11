import {
	AmbientLight,
	DirectionalLight,
	Mesh,
	MeshStandardMaterial,
	PerspectiveCamera,
	Scene,
	Vector3,
	WebGLRenderer,
} from 'three';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

export async function renderPrint(stage: HTMLElement, canvas: HTMLCanvasElement, src: string) {
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
	controls.target.set(0, 0, 0);
	controls.enableDamping = true;
	controls.dampingFactor = 0.08;
	controls.minDistance = radius * 0.5;
	controls.maxDistance = radius * 8;
	controls.update();

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

	let visible = true;
	document.addEventListener('visibilitychange', () => {
		visible = document.visibilityState === 'visible';
	});

	function animate() {
		requestAnimationFrame(animate);
		if (!visible) return;
		controls.update();
		renderer.render(scene, camera);
	}
	animate();
}
