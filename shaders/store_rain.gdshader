shader_type particles;
float rand(float x){return fract(sin(x*127.1+.1848)*43758.5453);}
void start(){TRANSFORM=EMISSION_TRANSFORM;TRANSFORM[3].xyz+=(vec3(rand(float(NUMBER)),0.,rand(float(NUMBER)+9.))-.5)*vec3(36.,0.,36.);VELOCITY=vec3(1.1,-15.,.3);}
void process(){
 vec3 before=TRANSFORM[3].xyz;TRANSFORM[3].xyz+=VELOCITY*DELTA;vec3 p=TRANSFORM[3].xyz;
 // Stop the whole 22 cm streak before its lower edge reaches the canvas.
 float roof=3.4-abs(p.x)*.23+.12;
 if(p.y<0.05 || (abs(p.x)<2.85 && p.z>-2.7 && p.z<1.5 && p.y<=roof))ACTIVE=false;
}
