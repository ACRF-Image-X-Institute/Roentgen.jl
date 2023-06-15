#=
    Depth and SSD Calculation

These tests computes the Source-Surface Distance (SSD) and depth of two points
and compares their value to precomputed values. The two points are located
on-axis and off-axis. It also compares SSD "scaling": points that are along the
same ray line return the same SSD.

Implemented Surfaces:
    - ConstantSurface
    - PlaneSurface
    - MeshSurface (uses the same mesh and visual inspection as detailed in meshes.jl)
=#

@testset "External Surfaces" begin

    function random_source(SAD)
        ϕ = 2π*rand()
        θ = π*rand()
        SAD*SVector(sin(ϕ)*cos(θ), cos(ϕ)*cos(θ), sin(θ))
    end

    random_position() = SVector((200*rand(3) .- 100)...)

    function test_surface(surf, pos, src, SSD_truth, depth_truth)
        @test getSSD(surf, pos, src) ≈ SSD_truth
        @test getdepth(surf, pos, src) ≈ depth_truth
    
        λ = 2*rand()
        pos2 = src + λ*(pos - src)
        @test getSSD(surf, pos2, src) ≈ SSD_truth

    end
    SAD = 1000.
    @test norm(random_source(SAD)) ≈ SAD

    @testset "ConstantSurface" begin
        SAD = 1000.
        SSD = 800.
        surf = ConstantSurface(SSD)

        src = random_source(SAD)
        pos = random_position()

        d = norm(pos - src) - SSD

        test_surface(surf, pos, src, SSD, d)
    end

    @testset "PlaneSurface" begin
        SAD = 1000.

        # 3-4-5 Triangle
        SSD₀ = 400. # Central axis source-surface distance
        ρ = 300.

        surf = PlaneSurface(SSD₀)

        SSD = √(SSD₀^2 + ρ^2)

        ϕ = rand()*2*π
        z = 20*rand()-10
        ρ′ = ρ*(SAD-z)/SSD₀

        src = SAD*SVector(0., 0., 1.)
        pos = SVector(ρ′*cos(ϕ), ρ′*sin(ϕ), z)
        
        d = norm(pos - src) - SSD

        @testset "3-4-5 Triangle" test_surface(surf, pos, src, SSD, d)

        # Rotationally Invariant
        @testset "Rotational Invariance" begin
            T = RotXYZ(RotXYZ(2π*rand(3)...))            
            test_surface(surf, T*pos, T*src, SSD, d)
        end
    end

    @testset "MeshSurface" begin
        structure = load_structure_from_ply("test_mesh.stl")
        surf = MeshSurface(structure)

        # Test 1 - Visually inspected for accuracy

        @testset "Visual Inspection 1" begin
            src = SVector(0., 0., 1000.)
            pos = SVector(0., 0., 0.)
            test_surface(surf, pos, src, 884.0906064830797, 115.90939351692032)
        end

        # Test 2 - Visually inspected for accuracy

        @testset "Visual Inspection 2" begin
            src = SVector(-335, 0., 942)
            pos = SVector(30., 20., 10.)

            test_surface(surf, pos, src, 875.0481662974585, 126.075702162384)
        end 
    end

    @testset "Cylindrical Surface" begin
        mesh = load_structure_from_ply("test_cylinder.stl")
        surf = CylindricalSurface(mesh; Δϕ°=1., Δy=1.)
        meshsurf = MeshSurface(mesh)

        @testset "Visual Inspection 1" begin
            src = SVector(0., 0., 1000.)
            pos = SVector(0., 0., 0.)

            @test getSSD(surf, pos, src) ≈ getSSD(meshsurf, pos, src) atol=0.01
        end
        
        @testset "Visual Inspection 2" begin
            src = SVector(-272.2, 100., 962.2)
            pos = SVector(67.9, -80.7, -2.6)

            @test getSSD(surf, pos, src) ≈ getSSD(meshsurf, pos, src) atol=0.01
        end
    end

    @testset "LinearSurface" begin

        function test_angle(surf, ϕg, SAD, SSDc)
        
            gantry = GantryPosition(ϕg, 0., SAD)
            src = DoseCalculations.getposition(gantry)
        
            T = RotY(ϕg)
        
            @testset "Along Central Axis" begin
                z = 20*rand().-10
                pos = T*SVector(0., 0., z)
                @test getSSD(surf, pos, src) ≈ SSDc
            end
        
            @testset "Off-Axis" begin
        
                R = 750.
                SSD = SSDc*√(1+(R/SAD)^2)
                
                θ = 2π*rand()
                z = 20*rand().-10
                α = (SAD-z)/SAD
        
                pos = T*SVector(α*R*sin(θ), α*R*cos(θ), z)
                @test getSSD(surf, pos, src) ≈ SSD
            end
        end

        SAD = 1000.
        
        ϕg = [0., π/3., π, 4*π/3, 2π]
        r = @. 50*cos(ϕg) + 550.
        x = @. r*sin(ϕg)
        z = @. r*cos(ϕg)
        
        SSDc = SAD.-r
        
        p = SVector.(x, 0., z)
        n = normalize.(p)
        
        surf = DoseCalculations.LinearSurface(ϕg, n, p)
        
        @testset "$(rad2deg(ϕg[i])), $(SSDc[i])" for i in eachindex(ϕg, SSDc)
            test_angle(surf, ϕg[i], SAD, SSDc[i])
        end
        
    end
end
