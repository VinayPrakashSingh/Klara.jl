#################################################################
#
#    Main file of MCMC.jl module
#
#################################################################

module MCMC

using DataFrames
using Distributions # logcdf() and Normal() are used in src/bayesglmmodels.jl (log-likelihood of Bayesian probit model)

import Base.*, Base.show
export show, *
export MCMCTask, MCMCChain

###########  Models and autodiff  ##########
include("modellers/mcmcmodels.jl")      #  include model types definitions		
include("modellers/bayesglmmodels.jl") # include Bayesian GLM models, such as logit and probit

include("modellers/parsing.jl")     #  include model expression parsing function
include("modellers/diff.jl")        #  include derivatives definitions
include("modellers/distributions.jl")    #  include distributions definitions

### MCMCTask type, generated by combining a MCMCModel with a MCMCSampler
type MCMCTask
  task::Task
  model::MCMCModel
end
reset(t::MCMCTask, x) = t.task.storage[:reset](x)

#############  samplers  ########################
include("samplers/samplers.jl")  # Common definitions for samplers

include("samplers/RWM.jl")    # Random-walk Metropolis sampler
include("samplers/MALA.jl")   # Metropolis adjusted Langevin algorithm sampler
include("samplers/HMC.jl")    # Hamiltonian Monte-Carlo sampler

#  Definition of * as a shortcut operator for model and sampler combination 
*{M<:MCMCModel, S<:MCMCSampler}(m::M, s::S) = spinTask(m, s)
*{M<:MCMCModel, S<:MCMCSampler}(m::Array{M}, s::S) = map((me) -> spinTask(me, s), m)
*{M<:MCMCModel, S<:MCMCSampler}(m::M, s::Array{S}) = map((se) -> spinTask(m, se), s)

### MCMCChain, the result of running a MCMCTask
type MCMCChain
  range::Range
  samples::DataFrame
  gradients::DataFrame
  diagnostics::DataFrame
  task::MCMCTask
  runTime::Float64
   
  function MCMCChain(r::Range, s::DataFrame, g::DataFrame, d::DataFrame, t::MCMCTask, rt::Float64)
    if !isempty(g); assert(size(s) == size(g), "samples and gradients must have the same number of rows and columns"); end
    if !isempty(d); assert(nrow(s) == nrow(d), "samples and diagnostics must have the same number of rows"); end
    new(r, s, g, d, t, rt)
  end
end

MCMCChain(r::Range, s::DataFrame, d::DataFrame, t::MCMCTask, rt::Float64) = MCMCChain(r, s, DataFrame(), d, t, rt)
MCMCChain(r::Range, s::DataFrame, t::MCMCTask, rt::Float64) = MCMCChain(r, s, DataFrame(), DataFrame(), t, rt)
MCMCChain(r::Range, s::DataFrame, d::DataFrame, t::MCMCTask) = MCMCChain(r, s, DataFrame(), d, t, NaN)
MCMCChain(r::Range, s::DataFrame, t::MCMCTask) = MCMCChain(r, s, DataFrame(), DataFrame(), t, NaN)

function show(io::IO, res::MCMCChain)
  println("$(nrow(res.samples)) parameters, $(ncol(res.samples)) samples (per parameter), $(round(res.runTime, 1)) sec.")
end

#############  runners    ########################

include("runners/run.jl")         # Vanilla runner
include("runners/seqMC.jl")       # Sequential Monte-Carlo runner
include("runners/serialMC.jl")    # Serial Tempering Monte-Carlo runner
end
