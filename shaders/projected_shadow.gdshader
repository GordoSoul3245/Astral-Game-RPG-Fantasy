shader_type canvas_item;
render_mode unshaded;
uniform vec2 sun;
uniform float daylight;
uniform vec3 hearth;
uniform vec3 gate;
varying float strength;

vec2 away(vec2 foot, vec3 lamp) {
	vec2 delta = foot - lamp.xy;
	float distance_px = length(delta);
	return delta / max(distance_px, 1.0) * (1.0 - smoothstep(0.0, max(lamp.z, 1.0), distance_px)) * step(1.0, lamp.z);
}

void vertex() {
	vec2 foot = MODEL_MATRIX[3].xy;
	vec2 local_light = away(foot, hearth) + away(foot, gate);
	float weight = min(length(local_light), 1.0) * (1.0 - daylight * 0.8);
	vec2 direction = mix(sun, normalize(local_light + vec2(0.00001)) * 0.76, weight);
	// Un extremo permanece apoyado en los pies incluso con luz rasante.
	float width = abs(VERTEX.x);
	float along = 1.0 - UV.y;
	float rise = max(-VERTEX.y, 0.0);
	vec2 axis = normalize(direction + vec2(0.0,0.001));
	vec2 across = vec2(axis.y,-axis.x);
	VERTEX = across * (UV.x*2.0-1.0)*width + direction*rise
		+ axis*(along*2.0-1.0)*width*0.34;
	strength = max(daylight, weight);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float rim = 1.0 - smoothstep(0.72, 1.0, dot(p,p));
	COLOR = vec4(0.065, 0.052, 0.12, rim * mix(0.09, 0.26, strength));
}
