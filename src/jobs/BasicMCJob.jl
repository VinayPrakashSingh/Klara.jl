### BasicMCJob

# BasicMCJob is used for sampling a single parameter via serial Monte Carlo
# It is the most elementary and typical Markov chain Monte Carlo (MCMC) job

type BasicMCJob{S<:VariableState} <: MCJob
  model::GenericModel # Model of single parameter
  pindex::Int # Index of single parameter in model.vertices
  parameter::Parameter # Points to model.vertices[pindex] for faster access
  sampler::MCSampler
  tuner::MCTuner
  range::BasicMCRange
  vstate::Vector{S} # Vector of variable states ordered according to variables in model.vertices
  pstate::ParameterState # Points to vstate[pindex] for faster access
  sstate::MCSamplerState # Internal state of MCSampler
  output::Union{VariableNState, VariableIOStream} # Output of model's single parameter
  count::Int # Current number of post-burnin iterations
  plain::Bool # If plain=false then job flow is controlled via tasks, else it is controlled without tasks
  task::Union{Task, Void}
  iterate!::Function
  consume!::Function
  reset!::Function
  save!::Function
  close::Function
  # checkin::Bool # If checkin=true then check validity of job constructors' input arguments, else don't check

  function BasicMCJob(
    model::GenericModel,
    pindex::Int,
    sampler::MCSampler,
    tuner::MCTuner,
    range::BasicMCRange,
    vstate::Vector{S},
    outopts::Dict{Symbol, Any}, # Options related to output
    plain::Bool,
    checkin::Bool
  )
    instance = new()

    instance.model = model
    instance.pindex = pindex
    instance.parameter = instance.model.vertices[instance.pindex]

    instance.sampler = sampler
    instance.tuner = tuner

    instance.range = range

    instance.vstate = vstate
    instance.pstate = instance.vstate[instance.pindex]
    initialize!(instance.pstate, instance.vstate, instance.parameter, sampler)

    instance.sstate = sampler_state(sampler, tuner, instance.pstate)

    augment!(outopts)
    instance.output = initialize_output(instance.pstate, range.npoststeps, outopts)

    instance.count = 0

    instance.plain = plain

    instance.iterate! = eval(codegen_iterate_basic_mcjob(instance, outopts))

    if plain
      instance.task = nothing
      instance.consume! = () -> instance.iterate!(
        instance.pstate,
        instance.vstate,
        instance.sstate,
        instance.parameter,
        instance.sampler,
        instance.tuner,
        instance.range
      )
      instance.reset! = x::Vector -> reset!(instance.pstate, instance.vstate, x, instance.parameter, instance.sampler)
    else
      instance.task = Task(() -> initialize_task!(
        instance.pstate,
        instance.vstate,
        instance.sstate,
        instance.parameter,
        instance.sampler,
        instance.tuner,
        instance.range,
        instance.iterate!
      ))
      instance.consume! = () -> consume(instance.task)
      instance.reset! = x::Vector -> reset(instance.task, x)
    end

    if outopts[:destination] == :nstate
      instance.save! = (i::Int) -> instance.output.copy(instance.pstate, i)
      instance.close = () -> ()
    elseif outopts[:destination] == :iostream
      instance.save! = (i::Int) -> instance.output.write(instance.pstate)
      instance.close = () -> close(instance.output)
    else
      error(":destination must be set to :nstate or :iostream or :none, got $(outopts[:destination])")
    end

    instance
  end
end

BasicMCJob{S<:VariableState}(
  model::GenericModel,
  pindex::Int,
  sampler::MCSampler,
  tuner::MCTuner,
  range::BasicMCRange,
  vstate::Vector{S},
  outopts::Dict{Symbol, Any}, # Options related to output
  plain::Bool,
  checkin::Bool
) =
  BasicMCJob{S}(model, pindex, sampler, tuner, range, vstate, outopts, plain, checkin)

# It is likely that MCMC inference for parameters of ODEs will require a separate ODEBasicMCJob
# In that case the iterate!() function will take a second variable (transformation) as input argument

function Base.run(job::BasicMCJob)
  for i in 1:job.range.nsteps
    job.consume!()

    if in(i, job.range.postrange)
      job.save!(job.count+=1)
    end
  end

  job.close()

  job.output
end
