using Revise
using WGPUCompute
using Test

function naive_reduce_kernel(x::WgpuArray{T, N}, out::WgpuArray{T, N}) where {T, N}
	gId = xDims.x*globalId.y + globalId.x
	W = Float32(xDims.x*xDims.y)
	steps = UInt32(ceil(log2(W)))
	out[gId] = x[gId]
	base=2.0
	for itr in 0:steps
		exponent = Float32(itr)
		stride = UInt32(pow(base, exponent))
		if gId%(2*stride) == 0
			out[gId] += out[gId + stride]
		end
		synchronize()
	end
end

function naive_reduce(x::WgpuArray{T, N}) where {T, N}
	y = WgpuArray{T}(undef, size(x))
	@wgpukernel(
		launch=true, 
		workgroupSizes=(4, 4),
		workgroupCount=(2, 2),
		shmem=(:shmem=>(Float32, (4, 4)),),
		naive_reduce_kernel(x, y)
	)
	return (y |> collect)[1]
end

x = WgpuArray{Float32}(rand(Float32, 8, 8))
z = naive_reduce(x)

x_cpu = (x |> collect)

sum_cpu = sum(x_cpu)
sum_gpu = (z |> collect)[1]

@test sum_cpu ≈ sum_gpu

