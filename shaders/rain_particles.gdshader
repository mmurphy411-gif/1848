shader_type particles;
// Integer hash: the former sin() hash lost precision at large drop numbers, so many
// drops shared one x and fell along the same lines, reading as film scratches.
// RANDOM_SEED changes every respawn (fixed by the tour), so drops do not repeat paths.
float hash(uint n) {
	n = (n ^ 61u) ^ (n >> 16u);
	n *= 9u;
	n = n ^ (n >> 4u);
	n *= 0x27d4eb2du;
	n = n ^ (n >> 15u);
	return float(n & 0x00ffffffu) / 16777216.0;
}
void start(){
 uint seed = RANDOM_SEED * 747796405u + NUMBER * 2891336453u;
 TRANSFORM=EMISSION_TRANSFORM;
 TRANSFORM[3].xyz+=(vec3(hash(seed),0.0,hash(seed+1u))-.5)*vec3(28.0,0.0,28.0);
 // Terminal speed of large drops, slanted by a light down-canyon wind (matches
 // `fall` in rain_streak.gdshader); each 0.45 m streak overlaps itself frame to frame.
 VELOCITY=vec3(1.6,-9.5-hash(seed+2u)*2.0,.5);
}
void process(){
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 vec3 p=TRANSFORM[3].xyz;
 float shore=-6.0+.0075*p.x*p.x;
 float ground=.12+max(0.0,p.z-shore)*.035;
 if(p.y<=max(0.0,ground))ACTIVE=false;
}
