shader_type sky;

uniform vec4 sky_top_color: source_color;
uniform vec4 sky_horizon_color: source_color;
uniform vec4 ground_horizon_color: source_color;
uniform vec4 ground_bottom_color: source_color;

uniform bool day_time;

uniform vec4 sun_color: source_color;
uniform float sun_radius = 2.0;
uniform vec4 moon_color: source_color;
uniform float moon_radius = 1.0;

uniform bool render_clouds = true;
uniform float coverage : hint_range(0.0, 1.0) = 0.23;     // Controls cloud coverage
uniform float thickness : hint_range(10.0, 100.0) = 55.0; // Controls cloud thickness
uniform float absorption : hint_range(0.1, 2.0) = 0.9;    // Controls light absorption in clouds
uniform vec2 wind_direction = vec2(1.0);
uniform float wind_force = 0.01;
uniform sampler3D cloud_noise;
uniform int march_steps : hint_range(0, 32, 1) = 8;  // Number of steps in ray marching

vec3 get_sky_color(vec3 eyedir) {
	vec3 sky_color;
	if(eyedir.y > 0.0){
		float col = clamp(eyedir.y / 0.075, 0.0, 1.0);
		sky_color = mix(sky_horizon_color, sky_top_color, col).rgb;
	}
	else{
		float col = clamp(eyedir.y / -0.075, 0.0, 1.0);
		sky_color = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, col);
	}
	
	if(day_time){
		float sun_amount = max(dot(eyedir, normalize(LIGHT0_DIRECTION)), 0.0);
		sky_color += sun_color.rgb * min(pow(sun_amount, 355.0) * sun_radius, 1.0);
		sky_color += sun_color.rgb * min(pow(sun_amount, 12.0) * 0.2, 1.0);
	} 
	else{
		float moon_amount = max(dot(eyedir, normalize(LIGHT0_DIRECTION)), 0.0);
		sky_color += moon_color.rgb * min(pow(moon_amount, 710.0) * moon_radius, 1.0);
		sky_color += moon_color.rgb * min(pow(moon_amount, 64.0) * 0.2, 1.0);
	}
	
	return sky_color;
}

//float hash(float n) {
    //return fract(sin(n) * 753.5453123);
//}
//
//float noise(vec3 x) {
    //vec3 p = floor(x);    // Integer part
    //vec3 f = fract(x);    // Fractional part
    //f = f * f * (3.0 - 2.0 * f);  // Smoothing function
    //
    //float n = p.x + p.y * 157.0 + 113.0 * p.z;
    //return mix(
        //mix(
            //mix(hash(n + 0.0), hash(n + 1.0), f.x),
            //mix(hash(n + 157.0), hash(n + 158.0), f.x),
            //f.y
        //),
        //mix(
            //mix(hash(n + 113.0), hash(n + 114.0), f.x),
            //mix(hash(n + 270.0), hash(n + 271.0), f.x),
            //f.y
        //),
        //f.z
    //);
//}
//
//float fbm_clouds(vec3 pos, float lacunarity, float init_gain, float gain) {
    //vec3 p = pos;
    //float H = init_gain;
    //float t = 0.0;
    //
    //for (int i = 0; i < 5; i++) {
        //t += abs(noise(p)) * H;
        //p *= lacunarity;
        //H *= gain;
    //}
    //return t;
//}

float fbm_clouds(vec3 position, float lacunarity, float init_gain, float gain){
	vec3 pos = position;
	float H = init_gain;
	float t = 0.0;
	
	for (int i = 0; i < 5; i++){
		t += abs(texture(cloud_noise, pos)).r * H;
		pos *= lacunarity;
		H *= gain;
	}
	
	return texture(cloud_noise, pos).r;
}

float cloud_density(vec3 position, float h, float time){
	vec3 pos = position + vec3(wind_direction.x, 0.0, wind_direction.y) * time * wind_force;
	float dens = fbm_clouds(pos * 0.000001 * 2.032, 2.6434, 0.5, 0.5);
	dens *= smoothstep(coverage, coverage + 0.035, dens);
	
	return dens;
}

vec4 render_cloud(vec3 eyedir, vec3 position, float time){
	float march_step = thickness / float(march_steps);
	vec3 projection = eyedir / eyedir.y;
	vec3 iter = projection * march_step;
	
	vec3 cloud_pos = position + projection * 120.0;
	float alpha = 0.0;
	vec3 cloud_color = vec3(0.0);
	float T = 1.0;
	
	if(eyedir.y > -0.05){
		for(int i = 0; i < march_steps; i++){
			float height = (cloud_pos.y - position.y) / thickness;
			float density = cloud_density(cloud_pos, height, time);
			
			float Ti = exp(-absorption * density * march_step);
			T *= Ti;
			
			cloud_color += T * exp(height) * density * march_step;
			alpha += (1.0 - Ti) * (1.0 - alpha);
			
			cloud_pos += iter;
			if(alpha > 0.99){
				break;
			}
		}
	}
	
	
	//vec3 p = (cloud_pos * 0.001 + vec3(wind_direction.x, 0.0, wind_direction.y) * time * wind_force);
	//float dens1 = fbm_clouds(p * 0.322, 2.2434, 0.55, 0.5);
	//float dens2 = fbm_clouds(p * 0.2, 2.0, 0.5, 0.52);
	//float dens3 = fbm_clouds(p * 0.2, 2.0, 0.52, 0.5);
	//
	//vec3 v3 = vec3(1.62);
	//v3.g *= dens2 + 0.2;
	//v3.b *= dens3 + 0.1;
	//v3 = clamp(v3, vec3(0.0), vec3(1.0));
	
	return vec4(pow(cloud_color , vec3(1.0, 0.9, 0.8)), alpha * 0.999);
}

void sky() {
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
	vec3 sky_color = get_sky_color(EYEDIR);
	if(render_clouds){
		vec4 cloud_color = render_cloud(EYEDIR, POSITION, TIME);
		
		sky_color = mix(sky_color, cloud_color.rgb, cloud_color.a);
	}
	
	//COLOR = cloud_color.rgb;
	COLOR = sky_color;
}
