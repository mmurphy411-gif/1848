// Bark and leaves share gust timing and the same bounded sway function.
float wind_sway(float time, float phase, float height, float weight) {
 float gust=.72+.28*sin(time*.19)*sin(time*.071+1.0);
 return (sin(time*.83+phase+height*.14)*.095+sin(time*1.91+phase*.73)*.045)*weight*gust;
}
