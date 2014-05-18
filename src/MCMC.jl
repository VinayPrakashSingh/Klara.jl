#################################################################
#
#    Main file of MCMC.jl module
#
#################################################################

module MCMC

using Distributions
using StatsBase

import Base.*, Base.show
export show, *
export MCMCTask, MCMCChain, MCMCLikModel, MCMCSampler, MCMCTuner, MCMCRunner

# Abstract types
abstract Model
abstract MCMCModel <: Model
abstract MCMCSampler
abstract MCMCTuner
abstract MCMCRunner

typealias FunctionOrNothing Union(Function, Nothing)
typealias MatrixF64OrNothing Union(Matrix{Float64}, Nothing)
typealias F64OrVectorF64 Union(Float64, Vector{Float64})

###########  model DSL parsing and translation  ##########
include("parsers/modelparser.jl")

###########  Models  ##########
include("modellers/models.jl")    
include("modellers/MCMCLikModel.jl")

### MCMCTask type, generated by combining a MCMCModel, a MCMCSampler and a MCMCRunner
type MCMCTask
  task::Task
  model::MCMCModel
  sampler::MCMCSampler
  runner::MCMCRunner
end
reset(t::MCMCTask, x) = t.task.storage[:reset](x)

#############  samplers  ########################
include("samplers/samplers.jl")  # Common definitions for samplers
include("samplers/IMH.jl")    # Independent Metropolis-Hastings sampler
include("samplers/RWM.jl")    # Random-walk Metropolis sampler
include("samplers/RAM.jl")    # Robust adaptive Metropolis sampler
include("samplers/MALA.jl")   # Metropolis adjusted Langevin algorithm sampler
include("samplers/HMC.jl")    # Hamiltonian Monte-Carlo sampler
include("samplers/HMCDA.jl")    # Adaptive Hamiltonian Monte-Carlo sampler with dual averaging
include("samplers/NUTS.jl")   # No U-Turn Hamiltonian Monte-Carlo sampler
include("samplers/SMMALA.jl") # Simplified manifold Metropolis adjusted Langevin algorithm sampler
include("samplers/PMALA.jl")  # Position-dependent Metropolis adjusted Langevin algorithm sampler
include("samplers/RMHMC.jl")  # Riemannian manifold Hamiltonian Monte Carlo sampler
include("samplers/SliceSampler.jl")  # Slice sampler

### MCMCChain, the result of running a MCMCTask
type MCMCChain
  range::Range{Int}
  samples::Matrix{Float64}
  logtargets::Vector{Float64}
  gradients::MatrixF64OrNothing
  diagnostics::Dict
  task::Union(MCMCTask, Array{MCMCTask})
  runTime::Float64
   
  function MCMCChain(r::Range{Int}, 
                     s::Matrix{Float64}, 
                     l::Vector{Float64}, 
                     g::MatrixF64OrNothing, 
                     d::Dict,
                     t::Union(MCMCTask, Array{MCMCTask}),
                     rt::Float64)
    @assert size(s,1) == size(l,1) "samples and logtargets do not have the same size"
    if g != nothing
      @assert size(s) == size(g) "samples and gradients must have the same number of rows and columns"
    end
    new(r, s, l, g, d, t, rt)
  end
end

MCMCChain(r::Range{Int}, s::Matrix{Float64}, l::Vector{Float64}, 
          d::Dict, t::Union(MCMCTask, Array{MCMCTask}), rt::Float64) = 
	MCMCChain(r, s, l, nothing,      d, t,    rt)

MCMCChain(r::Range{Int}, s::Matrix{Float64}, l::Vector{Float64}, 
          t::Union(MCMCTask, Array{MCMCTask}), rt::Float64) = 
	MCMCChain(r, s, l, nothing, Dict(), t,    rt)

MCMCChain(r::Range{Int}, s::Matrix{Float64}, l::Vector{Float64}, 
          d::Dict, t::Union(MCMCTask, Array{MCMCTask})) = 
	MCMCChain(r, s, l, nothing,      d, t,   NaN)

MCMCChain(r::Range{Int}, s::Matrix{Float64}, l::Vector{Float64}, 
          t::Union(MCMCTask, Array{MCMCTask})) = 
	MCMCChain(r, s, l, nothing, Dict(), t,   NaN)

function show(io::IO, res::MCMCChain)
  nsamples, npars = size(res.samples)
  println("$npars parameters, $nsamples samples (per parameter), $(round(res.runTime, 1)) sec.")
end

#  Definition of * as a shortcut operator for (model, sampler, runner) combination
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::M, s::S, r::R) = spinTask(m, s, r)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::Array{M}, s::S, r::R) = map((me) -> spinTask(me, s, r), m)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::M, s::Array{S}, r::R) = map((se) -> spinTask(m, se, r), s)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::M, s::S, r::Array{R}) = map((re) -> spinTask(m, s, re), r)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::Array{M}, s::Array{S}, r::R) =
  map((me, se) -> spinTask(me, se, r), m, s)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::Array{M}, s::S, r::Array{R}) =
  map((me, re) -> spinTask(me, s, re), m, r)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::M, s::Array{S}, r::Array{R}) =
  map((se, re) -> spinTask(m, se, re), s, r)
*{M<:MCMCModel, S<:MCMCSampler, R<:MCMCRunner}(m::Array{M}, s::Array{S}, r::Array{R}) =
  map((me, se, re) -> spinTask(me, se, re), m, s, r)

#############  runners    ########################
include("runners/runners.jl")
include("runners/SerialMC.jl") # Ordinary serial MCMC runner
include("runners/SerialTempMC.jl") # Serial Tempering Monte-Carlo runner
include("runners/SeqMC.jl") # Sequential Monte-Carlo runner

#############  MCMC output analysis and diagnostics    ########################
include("stats/mean.jl") # MCMC mean estimators
include("stats/var.jl") # MCMC variance estimators
include("stats/ess.jl") # Effective sample size and integrated autocorrelation time functions
include("stats/summary.jl") # Summary statistics for MCMCChain
include("stats/zv.jl")  # ZV-MCMC estimators
end
