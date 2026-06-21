shader_type spatial;

const int MAX_TEXTURES = 6;

uniform float uv_scale = 0.25;
uniform sampler2D[MAX_TEXTURES] textures : source_color;
uniform sampler2D[MAX_TEXTURES] normals;
uniform sampler2D[MAX_TEXTURES] ambient_occlusions;
uniform sampler2D[MAX_TEXTURES] roughness;
uniform float roughness_scale = 1.0;

uniform sampler2D blendNoise : repeat_enable, filter_linear;
uniform sampler2D tile_noise : source_color;
uniform float tile_offset = 1.0;

varying flat vec3 texture_ids;
varying vec3 bc_coords;
varying vec3 position;

const vec3 BC_COORDS[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void vertex() {
	// Called for every vertex the material is visible on.
	UV = VERTEX.xz * uv_scale;
	texture_ids[0] = COLOR.r*255.0;
	texture_ids[1] = COLOR.g*255.0;
	texture_ids[2] = COLOR.b*255.0;

	bc_coords = BC_COORDS[int(round(COLOR.a*255.0))];
	position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;;
}

vec4 sampleTexture(sampler2D[MAX_TEXTURES] samplers, int id, vec2 uv, vec2 duvdx, vec2 duvdy){
	vec4 color;
	for(int i = 0; i < MAX_TEXTURES; i++){
		if(i == id){
			color = texture(samplers[i], uv);
			color = textureGrad(samplers[i], uv, duvdx, duvdy);
		}
	}
	return color;
}

float blend_bezier(float center, float percent){
	float q1 = mix(0.0, center, percent);
	float q2 = mix(center, 1.0, percent);
	float r = mix(q1, q2, percent);
	return r;
}

vec4 color_from_bc(sampler2D[MAX_TEXTURES] samplers, vec3 bc, vec3 ids, vec2 uv, vec2 duvdx, vec2 duvdy) {
	vec4 color = vec4(0.0);
	for(int i = 0; i < 3; i++) {
		color += sampleTexture(samplers, int(ids[i]), uv, duvdx, duvdy) * bc[i];
	}
	return color;
}

vec3 textureNoTile(sampler2D[MAX_TEXTURES] samplers, vec3 bc, vec3 ids, vec2 uv, float v){
	float k = texture(tile_noise, 0.005 * uv).x; // cheap (cache friendly) lookup

	vec2 duvdx = dFdx(uv);
	vec2 duvdy = dFdy(uv);

	float l = k * 8.0;
	float f = fract(l);

	float ia = floor(l);
	float ib = ia + 1.0;

	vec2 offa = sin(vec2(3.0, 7.0) * ia); // can replace with any other hash
	vec2 offb = sin(vec2(3.0, 7.0) * ib); // can replace with any other hash

	vec3 cola = color_from_bc(samplers, bc, ids, uv + v * offa, duvdx, duvdy).xyz;
	vec3 colb = color_from_bc(samplers, bc, ids, uv + v * offb, duvdx, duvdy).xyz;
	vec3 ab = cola - colb;
	float sum_ab = ab.x + ab.y + ab.z;

	return mix(cola, colb, smoothstep(0.2, 0.8, f - 0.1 * sum_ab));
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec3 color;
	vec3 normal;
	float ao;
	float rough;
	vec2 uv = UV;
	vec3 bc = bc_coords;
	
	if (texture_ids[0] != texture_ids[1] || texture_ids[0] != texture_ids[2]) {
		float blend = texture(blendNoise, position.xz*0.25).x;
		
		bc = pow(bc, vec3(1.0/blend));
		
		float weight = bc.x + bc.y + bc.z;
		if (weight > 0.0) {
			bc /= weight;
		} else {
		    bc = vec3(0.333); // Fallback uniform blend
		}
	}

	color = textureNoTile(textures, bc, texture_ids, uv, tile_offset);
	normal = textureNoTile(normals, bc, texture_ids, uv, tile_offset);
	ao = textureNoTile(ambient_occlusions, bc, texture_ids, uv, tile_offset).r;
	rough = textureNoTile(roughness, bc, texture_ids, uv, tile_offset).r;

	ALBEDO = color;
	NORMAL_MAP = normal;
	AO = ao;
	ROUGHNESS = rough * roughness_scale;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
