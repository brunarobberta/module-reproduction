module reproduction
    
    implicit none
    private
    public :: repro, germination

    contains

    subroutine repro(temp, nppa, height1, seed_mass, n_seed) !, seed_bank) ??
        
        use global_par

        ! Declaração das variáveis de entrada
        
        !real(r_8), dimension(ntraits), intent(in) :: dt
        real(r_4), intent(in) :: temp
        real(r_8), intent(in) :: height1
        real(r_4), intent(in) :: nppa

        !outputs
    
        real(r_4), intent(out) :: n_seed
        real(r_4), intent(out) :: seed_mass

        ! Variáveis internas

        real(r_8) :: height
        real(r_8) :: seed_production
        real(r_4) :: new_seed_bank
    

        ! Calculando a massa da semente
        height = height1  ! Altura da planta em metros
        npp_rep = nppa*0.04 !4% of avilable NPP to reproduction

        seed_mass = (height / (10.0_r_8 ** 0.08_r_8)) ** (1.0_r_8 / 0.43_r_8)  ! Massa da semente em kg
        
        !print massa da semente
        print *, "Massa da semente:", seed_mass

        n_seed = npp_rep / seed_mass
        print *, "Tamanho do banco de sementes antes da produção:", n_seed
        
        !new_seed_bank = seed_bank + int(seed_production)  ! Convertendo para inteiro    
        
        !else
        !    new_seed_bank = seed_bank
        !endif
        !print *, "Tamanho do banco de sementes após a produção:", new_seed_bank


        ! Atualizando o banco de sementes
        !eed_bank = new_seed_bank

    end subroutine repro



    
end module reproduction