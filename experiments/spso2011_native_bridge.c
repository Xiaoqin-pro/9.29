#include "mex.h"
#include "main.h"
static const double *suppliedP0;
static const mxArray *objectiveHandle;
static int auditCalls,auditBudget,auditIterations,auditTopologyRebuilds,auditBoundaryClips;
static double *auditTrace;static double auditedBest;static double auditedVector[DMax];
#include "KISS.c"
double genrand64_real2(void){mexErrMsgIdAndTxt("SPSO:Option","Nonstandard RNG disabled");return 0;}
#include "alea_adapted.c"
#include "tools.c"
double perf(struct position x,int function,struct SS SS,double objective){
 mxArray *args[2],*ret=NULL;args[0]=(mxArray*)objectiveHandle;args[1]=mxCreateDoubleMatrix(1,SS.D,mxREAL);
 double *v=mxGetPr(args[1]);for(int d=0;d<SS.D;d++){v[d]=x.x[d];if(!mxIsFinite(v[d])||v[d]<SS.min[d]||v[d]>SS.max[d])mexErrMsgIdAndTxt("SPSO:Domain","Illegal objective input");}
 if(auditCalls>=auditBudget)mexErrMsgIdAndTxt("SPSO:FE","Objective cap exceeded");
 mxArray *err=mexCallMATLABWithTrap(1,&ret,2,args,"feval");mxDestroyArray(args[1]);
 if(err){mexCallMATLAB(0,NULL,1,&err,"rethrow");mexErrMsgIdAndTxt("SPSO:Objective","Objective failed");}
 double value=mxGetScalar(ret);mxDestroyArray(ret);if(!mxIsFinite(value))mexErrMsgIdAndTxt("SPSO:Finite","Nonfinite fitness");
 if(value<auditedBest){auditedBest=value;for(int d=0;d<SS.D;d++)auditedVector[d]=x.x[d];}
 auditTrace[auditCalls++]=auditedBest;return value;
}
#include "PSO_adapted.c"
void mexFunction(int nlhs,mxArray **plhs,int nrhs,const mxArray **prhs){
 if(nrhs!=6||nlhs!=4)mexErrMsgIdAndTxt("SPSO:Inputs","Expected handle,p0,lb,ub,budget,seed; four outputs");
 int N=(int)mxGetM(prhs[1]),D=(int)mxGetN(prhs[1]),budget=(int)mxGetScalar(prhs[4]);
 if(N!=40||D<1||D>DMax||budget<N)mexErrMsgIdAndTxt("SPSO:Shape","Invalid SPSO population/dimension/budget");
 suppliedP0=mxGetPr(prhs[1]);objectiveHandle=prhs[0];auditCalls=0;auditBudget=budget;auditIterations=0;auditTopologyRebuilds=0;auditBoundaryClips=0;auditedBest=INFINITY;
 struct problem pb={0};pb.SS.D=D;pb.SS.normalise=0;pb.SS.quantisation=0;pb.epsilon=-INFINITY;pb.evalMax=budget;
 const double *lb=mxGetPr(prhs[2]),*ub=mxGetPr(prhs[3]);for(int d=0;d<D;d++){pb.SS.min[d]=lb[d];pb.SS.max[d]=ub[d];}
 struct param param={0};param.S=N;param.w=1./(2*log(2.));param.c=.5+log(2.);param.K=3;param.p=1-pow(1-1./N,3);param.confin=0;param.distrib=0;param.topology=0;param.mean=.5;param.sigma=1./12;
 E=exp(1.);pi=acos(-1.);nBit=32;nCycleMax=1;nbRand=0;seed_rand_kiss((ulong)mxGetScalar(prhs[5]));
 plhs[2]=mxCreateDoubleMatrix(budget,1,mxREAL);auditTrace=mxGetPr(plhs[2]);
 struct result R=PSO(param,pb);if(auditCalls!=budget)mexErrMsgIdAndTxt("SPSO:FE","Final objective count mismatch");
 plhs[0]=mxCreateDoubleMatrix(1,D,mxREAL);for(int d=0;d<D;d++)mxGetPr(plhs[0])[d]=auditedVector[d];plhs[1]=mxCreateDoubleScalar(auditedBest);
 const char *names[]={"Evaluations","Iterations","TopologyRebuilds","UniformDraws","BoundaryClips","ReferenceFinalCost","KissX","KissY","KissZ","KissW","KissCarry"};
 plhs[3]=mxCreateStructMatrix(1,1,11,names);double values[]={auditCalls,auditIterations,auditTopologyRebuilds,nbRand,auditBoundaryClips,R.SW.P[R.SW.best].f,kiss_x,kiss_y,kiss_z,kiss_w,kiss_carry};
 for(int i=0;i<11;i++)mxSetField(plhs[3],0,names[i],mxCreateDoubleScalar(values[i]));
}
