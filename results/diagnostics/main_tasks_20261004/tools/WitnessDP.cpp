#include <iostream>
#include <fstream>
#include <vector>
#include <limits>
#include <algorithm>
#include <chrono>
#include <iomanip>
int main(int argc,char**argv){
 if(argc<2)return 1;std::ifstream in(argv[1]);int n;double speed,deadline;in>>n>>speed>>deadline;
 std::vector<double> ready(n),due(n),service(n);for(int i=0;i<n;i++)in>>ready[i]>>due[i]>>service[i];
 std::vector<double>L((n+1)*(n+1));for(auto &v:L)in>>v;
 unsigned states=1u<<n;double INF=1e25;std::vector<double>dp(size_t(states)*n,INF);std::vector<unsigned char>prev(size_t(states)*n,255);
 for(int j=0;j<n;j++){double start=std::max(ready[j],L[j+1]/speed);if(start<=due[j]+1e-9)dp[size_t(1u<<j)*n+j]=start+service[j];}
 unsigned long long reached=0,transitions=0;auto begin=std::chrono::steady_clock::now();
 for(unsigned mask=1;mask<states;mask++){
  unsigned lastbits=mask;
  while(lastbits){int i=__builtin_ctz(lastbits);lastbits&=lastbits-1;double now=dp[size_t(mask)*n+i];if(now>=INF)continue;reached++;
   unsigned remaining=(states-1)^mask;
   while(remaining){int j=__builtin_ctz(remaining);remaining&=remaining-1;transitions++;
    double start=std::max(ready[j],now+L[(i+1)*(n+1)+j+1]/speed);
    if(start>due[j]+1e-9)continue;unsigned next=mask|(1u<<j);size_t index=size_t(next)*n+j;double finish=start+service[j];
    if(finish<dp[index]){dp[index]=finish;prev[index]=(unsigned char)i;}
   }
  }
 }
 double best=INF;int last=-1;for(int i=0;i<n;i++){double value=dp[size_t(states-1)*n+i]+L[(i+1)*(n+1)]/speed;if(value<best){best=value;last=i;}}
 bool feasible=last>=0&&best<=deadline+1e-9;std::vector<int>route;
 if(feasible){unsigned mask=states-1;for(int k=n-1;k>=0;k--){route.push_back(last+1);int p=prev[size_t(mask)*n+last];mask^=1u<<last;last=p;}std::reverse(route.begin(),route.end());}
 std::cout<<std::setprecision(17)<<"{\"found\":"<<(feasible?"true":"false")<<",\"finish\":"<<(best<INF?best:-1)<<",\"reachedStates\":"<<reached<<",\"transitions\":"<<transitions<<",\"seconds\":"<<std::chrono::duration<double>(std::chrono::steady_clock::now()-begin).count()<<",\"route\":[";
 for(size_t i=0;i<route.size();i++){if(i)std::cout<<",";std::cout<<route[i];}std::cout<<"]}"<<std::endl;
}
