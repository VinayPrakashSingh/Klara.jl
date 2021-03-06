## SliceSamplerState holds the internal state ("local variables") of the slice sampler for multivariate parameters

type SliceSamplerState{F<:VariateForm} <: MCSamplerState{F}
  lstate::ParameterState{Continuous, F}
  rstate::ParameterState{Continuous, F}
  primestate::ParameterState{Continuous, F}
  tune::MCTunerState
  loguprime::Real
  runiform::Real
end

SliceSamplerState{F<:VariateForm}(
  lstate::ParameterState{Continuous, F},
  rstate::ParameterState{Continuous, F},
  primestate::ParameterState{Continuous, F},
  tune::MCTunerState=BasicMCTune()
) =
  SliceSamplerState(lstate, rstate, primestate, tune, NaN, NaN)

### Slice sampler

immutable SliceSampler <: MCSampler
  widths::RealVector # Step sizes for initially expanding the slice
  stepout::Bool # Protects against the case of passing in small widths

  function SliceSampler(widths::RealVector, stepout::Bool)
    @assert all(i -> i > 0, widths) "All widths must be positive"
    new(widths, stepout)
  end
end

SliceSampler(widths::RealVector) = SliceSampler(widths, true)

SliceSampler(widths::Real=1., n::Integer=1, stepout::Bool=true) = SliceSampler(fill(widths, n), stepout)

### Initialize slice sampler

## Initialize parameter state

function initialize!{F<:VariateForm}(
  pstate::ParameterState{Continuous, F},
  parameter::Parameter{Continuous, F},
  sampler::SliceSampler,
  outopts::Dict
)
  parameter.logtarget!(pstate)
  @assert isfinite(pstate.logtarget) "Log-target not finite: initial value out of support"
end

## Initialize SliceSampler state

sampler_state{F<:VariateForm}(
  parameter::Parameter{Continuous, F},
  sampler::SliceSampler,
  tuner::MCTuner,
  pstate::ParameterState{Continuous, F},
  vstate::VariableStateVector
) =
  SliceSamplerState(
    generate_empty(pstate),
    generate_empty(pstate),
    generate_empty(pstate),
    tuner_state(parameter, sampler, tuner)
  )

## Reset parameter state

function reset!(pstate::MultivariateParameterState, x::RealVector, parameter::MultivariateParameter, sampler::SliceSampler)
  pstate.value = copy(x)
  parameter.logtarget!(pstate)
end

function reset!{F<:VariateForm}(
  sstate::SliceSamplerState{F},
  pstate::ParameterState{Continuous, F},
  parameter::Parameter{Continuous, F},
  sampler::MCSampler,
  tuner::MCTuner
)
  tune.proposed, tune.totproposed = (0, tuner.period)
end

show(io::IO, sampler::SliceSampler) = print(io, "Slice sampler")
