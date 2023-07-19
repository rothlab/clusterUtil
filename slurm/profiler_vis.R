#!/usr/bin/env Rscript
options(stringsAsFactors=FALSE)

library(argparser)

p <- arg_parser(
  "visualize profiler data",
  name="profiler_vis.R",
  hide.opts=TRUE
)
p <- add_argument(p, "input", help="input profiler log file")
p <- add_argument(p, "--output", help="output file. Defaults to same name as input but with .pdf extension")
pargs <- parse_args(p)


infile <- pargs$input
if (!is.na(pargs$output)) {
  outfile <- pargs$output
} else {
  outfile <- sub("\\..+$",".pdf",infile)
}

cat("Reading data...\n")
data <- read.delim(infile)
data$Time <- as.POSIXct(sub("-"," ",data$Time))

cat("Drawing plot...\n")
pdf(outfile,11,8.5)
layout(rbind(1,2,3))
op <- par(oma=c(2,2,2,2),mar=c(0,4,4,1),lwd=2)
with(data,plot(
  Time,CPU...,
  type="l",ylab="CPU(%)",axes=FALSE,col="chartreuse3"
))
axis(2)
grid()
par(mar=c(0,4,0,1))
with(data,plot(
  Time,Threads,
  type="l",axes=FALSE,col="steelblue3"
))
axis(2)
grid()
par(mar=c(5,4,0,1))
with(data,plot(
  Time,Memory.KB./(2^20),
  type="l",ylab="Memory(GB)",col="gold",
  frame.plot=FALSE
))
grid()
par(op)
invisible(dev.off())

cat("Done!\n")
