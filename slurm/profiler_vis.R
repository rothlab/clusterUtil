
infile <- commandArgs(TRUE)[[1]]
data <- read.delim(infile)
data$Time <- as.POSIXct(sub("-"," ",data$Time))

layout(rbind(1,2,3))
op <- par(mar=c(0,4,4,1),lwd=2)
with(data,plot(Time,CPU...,type="l",ylab="CPU(%)",axes=FALSE,col="chartreuse3"))
axis(2)
grid()
par(mar=c(0,4,0,1))
with(data,plot(Time,Threads,type="l",axes=FALSE,col="steelblue3"))
axis(2)
grid()
par(mar=c(5,4,0,1))
with(data,plot(Time,Memory.KB./(2^20),type="l",ylab="Memory(GB)",col="gold",frame.plot=FALSE))
grid()
par(op)
