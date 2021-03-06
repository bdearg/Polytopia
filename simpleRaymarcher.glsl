
#define MaxSteps 80
#define MinimumDistance 0.0009
#define normalDistance     0.0002


#define Scale 3.0
#define FieldOfView 0.5
#define Jitter 0.06
#define FudgeFactor 1.0

#define Ambient 0.3
#define Diffuse 2.0
#define LightDir vec3(1.0)
#define LightColor vec3(0.3,0.3,0.3)
#define LightDir2 vec3(1.0,-1.0,1.0)
#define LightColor2 vec3(0.2,0.2,0.2)
#define Offset vec3(0.92858,0.92858,0.32858)

vec3 lightDir = LightDir;
vec3 lightDir2 = LightDir2;
vec3 spotDir = LightDir2;

// control-group: style
uniform float Refraction; // control[1, 0.01-1]

#define uD 2.0
#define uAO 0.04 


// Two light sources plus specular 
vec3 getLight(in vec3 color, in vec3 normal, in vec3 dir) {
	float diffuse = max(0.0,dot(normal, lightDir)); // Lambertian
	
	float diffuse2 = max(0.0,dot(normal, lightDir2)); // Lambertian
	

	vec3 r = spotDir - 2.0 * dot(normal, spotDir) * normal;
	float s = max(0.0,dot(dir,-r));
	
	vec3 r2 = vec3(-1,0,0) - 2.0 * dot(normal, vec3(-1,0,0)) * normal;
	float s2 = max(0.0,dot(dir,-r2));
	

	return
	
	(diffuse*Diffuse)*(LightColor*color) +
	(diffuse2*Diffuse)*(LightColor2*color) +pow(s,20.0)*vec3(0.3)+pow(s2,120.0)*vec3(0.3);
}

// Finite difference normal
vec3 getNormal(in vec3 pos) {
	vec3 e = vec3(0.0,normalDistance,0.0);
	
	return normalize(vec3(
			DE(pos+e.yxx)-DE(pos-e.yxx),
			DE(pos+e.xyx)-DE(pos-e.xyx),
			DE(pos+e.xxy)-DE(pos-e.xxy)
			)
		);
}

// Solid color 
vec3 getColor(vec3 normal, vec3 pos) {
	return vec3(0.2,0.13,0.94);
}


// Pseudo-random number
// From: lumina.sourceforge.net/Tutorials/Noise.html
float rand(vec2 co){
	return fract(cos(dot(co,vec2(4.898,7.23))) * 23421.631);
}

// Ambient occlusion approximation.
// Sample proximity at a few points in the direction of the normal.
float ambientOcclusion(vec3 p, vec3 n) {
	float ao = 0.0;
	float de = DE(p);
	float wSum = 0.0;
	float w = 1.0;
    float d = uD;
    float aoEps = uAO; // 0.04;
	for (float i =1.0; i <6.0; i++) {
		// D is the distance estimate difference.
		// If we move 'n' units in the normal direction,
		// we would expect the DE difference to be 'n' larger -
		// unless there is some obstructing geometry in place
		float D = (DE(p+ d*n*i*i*aoEps) -de)/(d*i*i*aoEps);
		w *= 0.6;
		ao += w*clamp(1.0-D,0.0,1.0);
		wSum += w;
	}
	return clamp(ao/wSum, 0.0, 1.0);
}


vec4 getMyColor(in vec3 pos,in vec3 normal, vec3 dir) {
	float ao = ambientOcclusion(pos,normal)*0.4;	
	vec4 color = baseColor(pos,normal);
	vec3 light = getLight(color.xyz, normal, dir);
	color.xyz = mix(color.xyz*Ambient+light,vec3(0),ao);
	return color;
}


vec4 rayMarch(in vec3 from, in vec3 dir) {
	// Add some noise to prevent banding
	float totalDistance = 0.;//Jitter*rand(fragCoord.xy+vec2(iTime));
	vec3 dir2 = dir;
	float distance;
	int steps = 0;
	vec3 pos;
	vec3 bestPos;
	float bestDist = 1000.0;
	float bestTotal = 0.0;
	vec3 acc = vec3(0.0);
	float rest = 1.0;
	
	float minDist = 0.0;
	float ior = Refraction;
	for (int i=0; i <= MaxSteps; i++) {
		pos = from + totalDistance * dir;
		distance = abs(DE(pos))*FudgeFactor;
		if (distance<bestDist) {
			bestDist = distance;
			bestPos = pos;
			bestTotal = totalDistance;
		}
		
		totalDistance += distance;
		
		if (distance < MinimumDistance && distance>minDist) {
		    minDist = distance;
			vec3 normal = getNormal(pos-dir*normalDistance*3.0);
			vec4 c = getMyColor(pos-dir*normalDistance*3.0,normal,dir);
			
			acc+=rest*c.xyz*c.w;
			rest*=(1.0-c.w);
			
			if (rest<0.1) break;
			
			
			totalDistance += 0.05;
			
			from = from + totalDistance * dir;
			totalDistance = 0.0;
			if (dot(dir,normal)>0.0) normal*=-1.0;
			dir = refract(dir, normal, ior);
			ior = 1.0/ior;
			bestDist = 1000.0;	
		}
		
		if (distance>minDist) minDist = 0.0;
		steps = i;
	}

	if (steps == MaxSteps) {
		pos = bestPos;
		vec3 normal = getNormal(pos-dir*normalDistance*3.0);
		vec4 c = getMyColor(pos,normal,dir);
		acc += rest*mix(c.xyz,vec3(1),min(bestDist/bestTotal*400.,1.0));
	}
	
	return vec4(pow(acc,vec3(0.6,0.5,0.5)),1.0);
} 


vec2 uv;
float rand(float c){
	return rand(vec2(c,1.0));
}

void main(void) {
	// This is taken from: https://raw.githubusercontent.com/mrdoob/three.js/master/examples/webgl_raymarching_reflect.html

	// screen position
	vec2 screenPos = ( gl_FragCoord.xy * 2.0 - resolution ) / resolution;

	// ray direction in normalized device coordinate
	vec4 ndcRay = vec4( screenPos.xy, 1.0, 1.0 );

	// convert ray direction from normalized device coordinate to world coordinate
	vec3 ray = ( cameraWorldMatrix * cameraProjectionMatrixInverse * ndcRay ).xyz;
	ray = normalize( ray );

	lightDir = normalize(cameraPosition+ vec3(1,1,1));
	lightDir2 = normalize(  vec3(-1,0,-1));
	spotDir = normalize(vec3(-0.,-1.,-1.));
	init();
	gl_FragColor = vec4( rayMarch(cameraPosition, ray));
}
