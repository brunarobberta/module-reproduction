! Copyright 2017- LabTerra

!     This program is free software: you can redistribute it and/or modify
!     it under the terms of the GNU General Public License as published by
!     the Free Software Foundation, either version 3 of the License, or
!     (at your option) any later version.

!     This program is distributed in the hope that it will be useful,
!     but WITHOUT ANY WARRANTY; without even the implied warranty of
!     MERCHANTABILITY or FITNESS FOR A PARTICULAR 2PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with this program.  If not, see <http://www.gnu.org/licenses/>.

! AUTHORS: *, JP Darela, Bianca Rius, Helena do Prado, David Lapola
! *This program is based on the work of those that gave us the INPE-CPTEC-PVM2 model

module photo

   ! Module defining functions related with CO2 assimilation and other processes in CAETE
   ! Some of these functions are based in CPTEC-PVM2, others are new features
   use types
   implicit none
   private



   ! functions(f) and subroutines(s) defined here
   public ::                    &
        gross_ph               ,& ! (f), gross photosynthesis (kgC m-2 y-1)
        leaf_area_index        ,& ! (f), leaf area index(m2 m-2)
        f_four                 ,& ! (f), auxiliar function (calculates f4sun or f4shade or sunlai)
        spec_leaf_area         ,& ! (f), specific leaf area (m2 g-1)
        sla_reich              ,& ! (f), specific leaf area (m2 g-1)
        water_stress_modifier  ,& ! (f), F5 - water stress modifier (dimensionless)
        photosynthesis_rate    ,& ! (s), leaf level CO2 assimilation rate (molCO2 m-2 s-1)
        vcmax_a                ,& ! (f), VCmax from domingues et al. 2010 (eq.1)
        vcmax_a1               ,& ! (f), VCmax from domingues et al. 2010 (eq.2)
        vcmax_b                ,& ! (f), VCmax from domingues et al. 2010 (eq.1 Table SM)
        canopy_resistence      ,& ! (f), Canopy resistence (from Medlyn et al. 2011a) (s/m)
        stomatal_conductance   ,& ! (f), IN DEVELOPMENT - return stomatal conductance
        vapor_p_defcit         ,& ! (f), Vapor pressure defcit  (kPa)
        transpiration          ,&
        tetens                 ,& ! (f), Maximum vapor pressure (hPa)
        nrubisco               ,& ! (f), Fraction of N not in lignin (disponible to rubisco)
        m_resp                 ,& ! (f), maintenance respiration (plants)
        sto_resp               ,&
        realized_npp           ,&
        spinup2                ,& ! (s), SPINUP function for CVEG pools
        spinup3                ,& ! (s), SPINUP function to check the viability of Allocation/residence time combinations
        g_resp                 ,& ! (f), growth Respiration (kg m-2 yr-1)
        pft_area_frac          ,& ! (s), area fraction by biomass
        water_ue               ,&
        leap                   ,&
        ttype                  ,&
        pls_allometry          ,& ! (s) Plant life strategies allometry (height, diameter, crown area) functions
        se_module                 ! (s) Subroutine to calculate SE (regulation)      
      !   density_ind            ,& ! (s) logic to density number (randon - to the inicialization)
      !   foliage_projective     ,&
      !   mort_occupation        ,& ! (s) logic to mortality relates to occupation/FPC
      !   mort_greff

contains

   subroutine ttype()
      use types

      type t1
      integer(i_4) :: att1
      integer(i_4) :: att2
      integer(i_4) :: att3
      end type t1

      type(t1), dimension(2) :: test
      integer(i_4) :: i
      test(1)%att1 = 23234523
      test(1)%att2 = 1223452
      test(1)%att3 = 4421524

      test(2)%att1 = 0
      test(2)%att2 = 0
      test(2)%att3 = 0


      do i = 1, 2
         print *, i, "ELEMENTO"
         print*, test(i)%att1
         print*, test(i)%att2
         print*, test(i)%att3
      enddo

   end subroutine ttype


   function leap(year) result(is_leap)
      use types

      integer(i_4),intent(in) :: year
      logical(l_1) :: is_leap

      logical(l_1) :: by4, by100, by400

      by4 = (mod(year,4) .eq. 0)
      by100 = (mod(year,100) .eq. 0)
      by400 = (mod(year,400) .eq. 0)

      is_leap = by4 .and. (by400 .or. (.not. by100))

   end function leap

   !=================================================================
   !=================================================================

   function gross_ph(f1,cleaf,sla_var) result(ph)
      ! Returns gross photosynthesis rate (kgC m-2 y-1) (GPP)
      use types, only: r_4, r_8
      !implicit none

      real(r_8),intent(in) :: f1    !molCO2 m-2 s-1
      real(r_8),intent(in) :: cleaf !kgC m-2
      real(r_8),intent(in) :: sla_var   !m2 gC-1
      real(r_4) :: ph

      real(r_8) :: f4sun, f1in
      real(r_8) :: f4shade

      f1in = f1
      f4sun = f_four(1,cleaf,sla_var)
      f4shade = f_four(2,cleaf,sla_var)

      ph = real((0.012D0*31557600.0D0*f1in*f4sun*f4shade), r_4)
      if(ph .lt. 0.0) ph = 0.0
   end function gross_ph

   !=================================================================
   !=================================================================

   function leaf_area_index(cleaf, sla_var) result(lai)
      ! Returns Leaf Area Index m2 m-2

      use types, only: r_8
      !implicit none

      real(r_8),intent(in) :: cleaf !kgC m-2
      real(r_8),intent(in) :: sla_var   !m2 gC-1
      real(r_8) :: lai


      lai  = cleaf * 1.0D3 * sla_var  ! Converts cleaf from (KgC m-2) to (gCm-2)
      if(lai .lt. 0.0D0) lai = 0.0D0

   end function leaf_area_index

   !=================================================================
   !=================================================================

   function spec_leaf_area(tau_leaf) result(sla)
      ! based on JeDi DGVM
      use types, only : r_8
      !implicit none

      real(r_8),intent(in) :: tau_leaf  !years
      real(r_8):: sla   !m2 gC-1

      ! real(r_8) :: n_tau_leaf, tl0

      ! n_tau_leaf = (tau_leaf - 0.08333333)/(8.33333333 - 0.08333333)

      ! ! tl0 = (365.242D0 / 12.0D0) * (10.0D0 ** (2.0D0*n_tau_leaf))
      ! ! Tweak the function to 'convert' Leaf Longevity to C residence time (MRT) 
      ! tl0 = ((365.242D0 / 12.0D0) - 10.45) * (2.718281828459045D0 ** (2.0D0*n_tau_leaf))

      sla = sla_reich(tau_leaf) * 0.0001 !(3D-2 * (365.2420D0 / tl0) ** (-0.460D0))

   end function spec_leaf_area

   !=================================================================
   !=================================================================
   function sla_reich(tau_leaf) result(sla)
      ! based on Reich et al. 1997
      use types, only : r_8
      !implicit none

      real(r_8),intent(in) :: tau_leaf  !years
      real(r_8):: sla   !cm2 gC-1

      real(r_8) :: tl0

      tl0 = tau_leaf * 12.0D0

      sla = 266.0D0 * (tl0 ** (-0.55)) 

   end function sla_reich

   !=================================================================
   !=================================================================

   function f_four(fs,cleaf,sla_var) result(lai_ss)
      ! Function used to scale LAI from leaf to canopy level (2 layers)
      use types, only: i_4, r_4, r_8
      use photo_par, only: p26, p27
      !implicit none

      integer(i_4),intent(in) :: fs !function mode:
      ! 1  == f4sun   --->  to gross assimilation
      ! 2  == f4shade --->  too
      ! 90 == sun LAI
      ! 20 == shade LAI
      ! Any other number returns sunlai (not scaled to canopy)

      real(r_8),intent(in) :: cleaf ! carbon in leaf (kg m-2)
      real(r_8),intent(in) :: sla_var   ! specific leaf area (m2 gC-1)
      real(r_8) :: lai_ss           ! leaf area index (m2 m-2)

      real(r_8) :: lai
      real(r_8) :: sunlai
      real(r_8) :: shadelai

      lai = leaf_area_index(cleaf, sla_var)

      sunlai = (1.0D0-(dexp(-p26*lai)))/p26
      shadelai = lai - sunlai

      lai_ss = sunlai

      if (fs .eq. 90) then
         return
      endif
      if (fs .eq. 20) then
         lai_ss = shadelai
         return
      endif

      !Scaling-up to canopy level (dimensionless)
      !------------------------------------------
      !Sun/Shade approach to canopy scaling !Based in de Pury & Farquhar (1997)
      !------------------------------------------------------------------------
      if(fs .eq. 1) then
         ! f4sun
         lai_ss = (1.0-(dexp(-p26*sunlai)))/p26 !sun decl 90 degrees
         return
      endif

      if(fs .eq. 2) then
         !f4shade
         lai_ss = (1.0-(dexp(-p27*shadelai)))/p27 !sun decl ~20 degrees
         return
      endif
   end function f_four

   !=================================================================
   !=================================================================

   function water_stress_modifier(w, cfroot, rc, ep, wmax) result(f5)
      use types, only: r_4, r_8
      use global_par, only: csru, alfm, gm, rcmin, rcmax
      !implicit none

      real(r_8),intent(in) :: w      !soil water mm
      real(r_8),intent(in) :: cfroot !carbon in fine roots kg m-2
      real(r_4),intent(in) :: rc     !Canopy resistence 1/(micromol(CO2) m-2 s-1)
      real(r_4),intent(in) :: ep
      real(r_8),intent(in) :: wmax     !potential evapotranspiration
      real(r_8) :: f5


      real(r_8) :: pt, rc_aux, rcmin_aux, ep_aux
      real(r_8) :: gc
      real(r_8) :: wa
      real(r_8) :: d
      real(r_8) :: f5_64

      wa = w/wmax
      rc_aux = real(rc, kind=r_8)
      rcmin_aux = real(rcmin, kind=r_8)
      ep_aux = real(ep, kind=r_8)
      if (rc .gt. rcmax) rc_aux = real(rcmax, r_8)

      pt = csru*(cfroot*1000.0D0) * wa  !(based in Pavlick et al. 2013; *1000. converts kgC/m2 to gC/m2)
      if(rc_aux .gt. rcmin) then
         gc = (1.0D0/(rc_aux * 1.15741D-08))  ! s/m
      else
         gc =  1.0D0/(rcmin_aux * 1.15741D-8) ! BIANCA E HELENA - Mudei este esquema..
      endif

      !d =(ep * alfm) / (1. + gm/gc) !(based in Gerten et al. 2004)
      d = (ep_aux * alfm) / (1.0D0 + (gm/gc))
      if(d .gt. 0.0D0) then
         f5_64 = pt/d
         ! print*, f5_64, 'f564'
         f5_64 = exp((f5_64 * (-0.1D0)))
         f5_64 = 1.0D0 - f5_64
      else
         f5_64 = wa
      endif

      f5 = f5_64
      if (f5 .lt. 0.0D0) f5 = 0.0D0
   end function water_stress_modifier

   ! =============================================================
   ! =============================================================

   function canopy_resistence(vpd_in,f1_in,g1,ca) result(rc2_in)
      ! return stomatal resistence based on Medlyn et al. 2011a
      ! Coded by Helena Alves do Prado
      use global_par, only: rcmin, rcmax
      use types, only: r_4 ,r_8


      !implicit none

      real(r_8),intent(in) :: f1_in    !Photosynthesis (molCO2/m2/s)
      real(r_4),intent(in) :: vpd_in   !hPa
      real(r_8),intent(in) :: g1       ! model m (slope) (sqrt(kPa))
      real(r_8),intent(in) :: ca
      real(r_4) :: rc2_in              !Canopy resistence (sm-1)

      !     Internal
      !     --------
      real(r_8) :: gs       !Canopy conductance (molCO2 m-2 s-1)
      real(r_8) :: D1       !sqrt(kPA)
      real(r_4) :: vapour_p_d

      vapour_p_d = vpd_in
      ! Assertions
      if(vpd_in .le. 0.0) vapour_p_d = 0.001
      if(vpd_in .gt. 4.0) vapour_p_d = 4.0
      ! print *, 'vpd going mad in canopy_resistence'
      ! stop
      ! endif

      D1 = sqrt(vapour_p_d)
      gs = 0.003 + 1.6D0 * (1.0D0 + (g1/D1)) * ((f1_in * 1.0e6)/ca) ! mol m-2 s-1
      gs = gs * (1.0D0 / 44.6D0)! convrt from  mol/m²/s to m s-1
      rc2_in = real( 1.0D0 / gs, r_4)  !  s m-1

      if(rc2_in .ge. rcmax) rc2_in = rcmax
      if(rc2_in .lt. rcmin) rc2_in = rcmin

   end function canopy_resistence

   !=================================================================
   !=================================================================

   function stomatal_conductance(vpd_in,f1_in,g1,ca) result(gs)
    ! return stomatal resistence based on Medlyn et al. 2011a
    ! Coded by Helena Alves do Prado

    use types, only: r_4 ,r_8

    !implicit none

    real(r_4),intent(in) :: f1_in    !Photosynthesis (molCO2/m2/s)
    real(r_4),intent(in) :: vpd_in   !hPa
    real(r_4),intent(in) :: g1       ! model m (slope) (sqrt(kPa))
    real(r_8),intent(in) :: ca
    real(r_8) :: gs       !Canopy conductance (molCO2 m-2 s-1)
    !     Internal
    !     --------
    real(r_8) :: D1       !sqrt(kPA)
    real(r_4) :: vapour_p_d

    vapour_p_d = vpd_in
    ! Assertions
    if(vpd_in .le. 0.0) vapour_p_d = 0.001
    if(vpd_in .gt. 4.0) vapour_p_d = 4.0
    ! print *, 'vpd going mad in canopy_resistence'
    ! stop
    ! endif

    D1 = sqrt(vapour_p_d)
    gs = 1.6 * (1.0 + (g1/D1)) * (f1_in/ca) !mol m-2 s-1
 end function stomatal_conductance

 !=================================================================
 !=================================================================

   function water_ue(a, g, p0, vpd) result(wue)
      use types
      !implicit none
      real(r_8),intent(in) :: a
      real(r_4),intent(in) :: g, p0, vpd
      ! a = assimilacao; g = resistencia; p0 = pressao atm; vpd = vpd
      real(r_4) :: wue

      real(r_4) :: g_in, p0_in, e_in

      g_in = (1./g) * 40.87 ! convertendo a resistencia (s m-1) em condutancia mol m-2 s-1
      p0_in = p0 /10. ! convertendo pressao atm (mbar/hPa) em kPa
      e_in = g_in * (vpd/p0_in) ! calculando transpiracao mol H20 m-2 s-1

      if(a .eq. 0 .or. e_in .eq. 0) then
         wue = 0
      else
         wue = real(a, kind=r_4)/e_in
      endif
   end function water_ue


 !=================================================================
 !=================================================================

   function transpiration(g, p0, vpd, unit) result(e)
      use types
      !implicit none
      real(r_4),intent(in) :: g, p0, vpd
      integer(i_4), intent(in) :: unit
      ! g = resistencia estomatica s m-1; p0 = pressao atm (mbar == hPa); vpd = vpd (kPa)
      real(r_4) :: e

      real(r_4) :: g_in, p0_in, e_in

      g_in = (1./g) * 44.6 ! convertendo a resistencia (s m-1) (m s-1) em condutancia mol m-2 s-1
      p0_in = p0 / 10. ! convertendo pressao atm (mbar/hPa) em kPa

      e_in = g_in * (vpd/p0_in) ! calculando transpiracao mol H20 m-2 s-1

      if(unit .eq. 1) then
         e = e_in
         return
      else
         e = 18.0 * e_in * 1e-3    ! g m-2 s-1 * 1d-3  == Kg m-2 s-1  == mm s-1
      endif
   end function transpiration


   !=================================================================
   !=================================================================

   function vapor_p_defcit(t,rh) result(vpd_0)
      use types
      !implicit none

      real(r_4),intent(in) :: t
      real(r_4),intent(in) :: rh

      real(r_4) :: es
      real(r_4) :: vpd_ac
      real(r_4) :: vpd_0

      ! ext func
      !real(r_4) :: tetens

      es = tetens(t)

      !     delta_e = es*(1. - ur)
      !VPD-REAL = Actual vapor pressure
      vpd_ac = es * rh       ! RESULT in hPa == mbar! we want kPa (DIVIDE by 10.)
      !Vapor Pressure Deficit
      vpd_0 = (es - vpd_ac) / 10.
   end function vapor_p_defcit

!=================================================================
!=================================================================

   subroutine realized_npp(pot_npp_pool, nupt_pot, available_n,&
      &  rnpp, nl)

      use types
      implicit none
      real(r_8), intent(in) :: pot_npp_pool ! POTENTIAL NPP (POOL - leaf, root or wood)
      real(r_8), intent(in) :: nupt_pot     ! POTENTIAL UPTAKE OF NUTRIENT(N/P)for each pool
      real(r_8), intent(in) :: available_n  ! AVAILABLE NUTRIENTS FOR GROWTH weighted for each pool

      real(r_8), intent(out) :: rnpp        ! REALIZED NPP
      logical(l_1), intent(out) :: nl       ! IS LIMITED?

      ! NUTRIENT LIMITED NPP TO(CVEGpool):
      if (available_n .ge. nupt_pot) then
         ! THere is NO LIMITATION in this case
         nl = .false.
         ! GROWTH IS ACCOMPLISHED (all npp can go to the CVEG pool)
         rnpp = pot_npp_pool
      else
         ! NPP OF THIS POOL IS LIMITED BY Nutrient X
         ! In this case the realized NPP for the pool is smaller than the Potential POOL
         nl = .true.
         ! ACOMPLISHED NPP
         rnpp = max( 0.0D0, (available_n * pot_npp_pool) / nupt_pot)
      endif

      end subroutine realized_npp

   !=================================================================
   !=================================================================
   ! def nrubisco(leaf_t, n_in):
      ! from math import e

      ! tl = e**(-(leaf_t + 1.03)) + 0.08

      ! return tl * (n_in * 0.7)
   function nrubisco(leaf_t,n_in) result(nb)
      use types
      real(r_8), intent(in) :: leaf_t
      real(r_8), intent(in) :: n_in
      real(r_8) :: nb, tl
      real(r_8) :: e = 2.718281828459045D0

      tl = e**(-(leaf_t + 1.2)) + 0.04

      nb = tl * n_in

   end function nrubisco

   !=================================================================
   !=================================================================
   function vcmax_a(npa, ppa, sla_var) result(vcmaxd)
      ! TESTING eq.1 / Fig 5 Domingues et al. 2010
      real(r_8), intent(in) :: npa       ! N mg g-1
      real(r_8), intent(in) :: ppa       ! P mg g-1
      real(r_8), intent(in) :: sla_var       ! m2(Leaf) g(C)-1

      
      real(r_8) :: vcmaxd !mol m⁻² s⁻¹
      
      real(r_8), parameter :: alpha_n = -1.16D0,&
                              nu_n    = 0.70D0,&
                              alpha_p = -0.30D0,&
                              nu_p    = 0.85D0
                              
      real(r_8) :: ndw, pdw, lma, nlim, plim, vcmax_dw
      
      ndw = npa
      pdw = ppa

      lma = sla_var ** (-1) ! g/m2

      ! CALCULATE VCMAX
      nlim = alpha_n + nu_n * dlog10(ndw)  ! + (sigma_n * dlog10(sla))
      plim = alpha_p + nu_p * dlog10(pdw)  ! + (sigma_p * dlog10(sla))
      
      vcmax_dw = min(10**nlim, 10**plim) ! log10(vcmax_dw) in µmol g⁻¹ s⁻¹
      vcmaxd = vcmax_dw * lma * 1.0D-6 ! Multiply by LMA to have area values and 1d-6 to mol m-2 s-1

   end function vcmax_a

   !=================================================================
   !=================================================================
   function vcmax_a1(npa, ppa, sla_var) result(vcmaxd)
      ! TESTING
      real(r_8), intent(in) :: npa   ! N g m-2
      real(r_8), intent(in) :: ppa,sla_var   ! P g m-2 / m2 g-1

      
      real(r_8) :: vcmaxd !mol m⁻² s⁻¹

      ! UNITS = LMA Domingues = cm2 g-1 (SLA CAETE = m² g⁻¹)
      ! Dry weight -> mg g⁻¹
      
      real(r_8), parameter :: alpha_n = -1.56D0,&
                              nu_n    = 0.43D0,&
                              alpha_p = -0.80D0,&
                              nu_p    = 0.45D0,&
                              sigma_n = 0.37D0,&
                              sigma_p = 0.25D0
                              
      real(r_8) :: ndw, pdw, lma, nlim, plim, vcmax_dw
      
      ndw = npa
      pdw = ppa

      lma = sla_var ** (-1) ! g/m2

      ! CALCULATE VCMAX
      nlim = alpha_n + nu_n * dlog10(ndw)  + (sigma_n * dlog10(sla_var))
      plim = alpha_p + nu_p * dlog10(pdw)  + (sigma_p * dlog10(sla_var))
      
      vcmax_dw = min(10**nlim, 10**plim) ! log10(vcmax_dw) in µmol g⁻¹ s⁻¹
      vcmaxd = vcmax_dw * lma

   end function vcmax_a1

   !=================================================================
   !=================================================================
   function vcmax_b(npa) result(vcmaxd)
      ! TESTING Domingues f
      real(r_8), intent(in) :: npa   ! N g m-2
      ! real(r_8), intent(in) :: ppa   ! P g m-2

      
      real(r_8) :: vcmaxd !mol m⁻² s⁻¹

      real(r_8), parameter :: a = 1.57D0 ,&
                              b = 0.55D0                             
      real(r_8) :: ndw

      ! CALCULATE VCMAX
      ndw = a + (b * dlog10(npa)) 
      vcmaxd = 10**ndw * 1D-6 


   end function vcmax_b
   !=================================================================
   !=================================================================

   subroutine photosynthesis_rate(c_atm, temp,p0,ipar,sla_var,c4,nbio,pbio,&
        & cleaf,cawood1,height1,max_height,f1ab,vm, amax)

      ! f1ab SCALAR returns instantaneous photosynthesis rate at leaf level (molCO2/m2/s)
      ! vm SCALAR Returns maximum carboxilation Rate (Vcmax) (molCO2/m2/s)
      use types
      use global_par
      use photo_par
      ! implicit none
      ! I
      real(r_4),intent(in) :: temp  ! temp °C
      real(r_4),intent(in) :: p0    ! atm Pressure hPa
      real(r_4),intent(in) :: ipar  ! mol Photons m-2 s-1
      real(r_8),intent(in) :: nbio, c_atm  ! mg g-1, ppm
      real(r_8),intent(in) :: pbio  ! mg g-1
      ! logical(l_1),intent(in) :: ll ! is light limited?
      integer(i_4),intent(in) :: c4 ! is C4 Photosynthesis pathway?
      ! real(r_8),intent(in) :: leaf_turnover   ! y
      real(r_8),intent(in) :: sla_var
      real(r_8),intent(in) :: height1
      real(r_8),intent(in) :: max_height
      real(r_8),intent(in) :: cawood1
      real(r_8),intent(in) :: cleaf

      ! O
      real(r_8),intent(out) :: f1ab ! Gross CO2 Assimilation Rate mol m-2 s-1
      real(r_8),intent(out) :: vm   ! PLS Vcmax mol m-2 s-1
      real(r_8),intent(out) :: amax ! light saturated PH rate



      real(r_8) :: f2,f3            !Michaelis-Menten CO2/O2 constant (Pa)
      real(r_8) :: mgama,vm_in      !Photo-respiration compensation point (Pa)
      real(r_8) :: rmax, r
      real(r_8) :: ci
      real(r_8) :: jp1
      real(r_8) :: jp2
      real(r_8) :: jp
      real(r_8) :: jc
      real(r_8) :: jl
      real(r_8) :: je,jcl
      real(r_8) :: b,c,c2,b2,es,j1,j2
      real(r_8) :: delta, delta2,aux_ipar
      real(r_8) :: f1a

      ! new vars C4 PHOTOSYNTHESIS
      real(r_8) :: ipar1
      real(r_8) :: tk           ! (K)
      real(r_8) :: t25          ! tk at 25°C (K)
      real(r_8) :: kp
      real(r_8) :: dummy0, dummy1, dummy2
      real(r_8) :: vpm, v4m
      real(r_8) :: cm, cm0, cm1, cm2

      ! real(r_8) :: vm_nutri
      real(r_8) :: nbio2, pbio2  ! , cbio_aux
      ! real(r_8) :: nmgg, pmgg
      ! real(r_8) :: coeffa, coeffb

      !Internal Variables [LIGHT COMPETITION] ---------------------------------------
      integer(i_4) :: n
      real(r_8) :: index_leaf
      integer(i_4) :: num_layer !number of layers according to max height in each grid-cel
      real(r_8) :: layer_size !size of each layer in m. in each grid-cell
      integer(i_4) :: last_with_pls !last layer contains PLS
      real(r_8) :: llight
      !real(r_8) :: f1ab_layer

      type :: layer_array
         real(r_8) :: sum_height
         integer(i_4) :: num_height !!corresponds to the number of layers according max height of PLS.
         real(r_8) :: mean_height !Mean of heights in a layer
         real(r_8) :: layer_height !Height of respective layer of the floor (in m.)
         real(r_8) :: sum_lai !LAI sum in a layer
         real(r_8) :: mean_lai !mean LAI in a layer
         real(r_8) :: beers_law !layer's light extinction
         real(r_8) :: linc !layer's light incidence
         real(r_8) :: lused !layer's light used (relates to light extinction - Beers Law)
         real(r_8) :: lavai !light availability
         integer(i_4) :: layer_id !identify layers
      end type layer_array

      type(layer_array), allocatable :: layer(:)

      nbio2 = nbio !nrubisco(leaf_turnover, nbio)
      pbio2 = pbio !nrubisco(leaf_turnover, pbio)
      aux_ipar = 0.0D0 !inicialize

      ! if (nbio2 .lt. 0.01D0) nbio2 = 0.01D0
      ! if (pbio2 .lt. 0.01D0) pbio2 = 0.01D0

      ! ! ! Calculation of reference carboxilation rate of rubisco
      ! !### WALKER et al. 2014
      ! vm_nutri = 3.946D0 + (0.921D0 * dlog(nbio2)) - (0.121D0 * dlog(pbio2))
      ! vm_nutri = vm_nutri + (0.282D0 * dlog(nbio2) * dlog(pbio2))
      ! vm = (dexp(vm_nutri)) * 1.0D-6 ! Vcmax convert µmol m-2 s-1 to mol m-2 s-1

      ! ! !### DOMINGUES et al. 2010
      ! cbio_aux = cbio
      ! if(cbio .le. 0.0D0) cbio_aux = 0.01D0

      ! nmgg = nbio2 / cbio_aux ! g(Nutrient) kg(Carbon)-1
      ! pmgg = pbio2 / cbio_aux ! g(Nutrient) kg(Carbon)-1
      
      ! coeffa = 1.57D0
      ! coeffb = 0.55D0

      ! vm_nutri = coeffa + (coeffb * dlog10(nbio2))

      ! vm = vcmax_a(nbio2, pbio2, spec_leaf_area(leaf_turnover)) ! 10**vm_nutri * 1D-6  !
      vm = vcmax_a(nbio2, pbio2, sla_var) ! 10**vm_nutri * 1D-6  ! 
      if(vm + 1 .eq. vm) vm = 1.0D-5 ! If Vc max is inf give it a low value
      if(vm .gt. p25) vm = p25

      ! Rubisco Carboxilation Rate - temperature dependence
      vm_in = (vm*2.0D0**(0.1D0*(temp-25.0D0)))/(1.0D0+dexp(0.3D0*(temp-36.0)))
      if(vm_in + 1 .eq. vm_in) vm_in = p25 - 5.0D-5
      if(vm_in .gt. p25) vm_in = p25


      !========================= LIGHT COMPETITION =============================!
      !         Code by: Bárbara Cardeli, Bianca Rius and Caio Fascina          !
      !                               START                                     !

      index_leaf = leaf_area_index(cleaf, sla_var)

      ! =================================================
      !       LIGHT COMPETITION DYNAMIC. [LAYERS]
      ! =================================================

      num_layer = 0
      layer_size = 0.0D0

      num_layer = nint(max_height/5)
      ! print*, 'num layer is', num_layer, 'max_height=', max_height

      allocate(layer(1:num_layer))

      layer_size = max_height/num_layer !length from one layer to another
      ! print*, 'layer_size', layer_size
     
      last_with_pls=num_layer
      !print*, 'LAST', last_with_pls

      do n = 1,num_layer
         layer(n)%layer_height = 0.0D0
         layer(n)%layer_height=layer_size*n
      end do

      do n = 1, num_layer
         !Inicialize variables relates layers dynamics
         layer(n)%num_height = 0.0D0
         layer(n)%sum_height = 0.0D0
         layer(n)%mean_height = 0.0D0
         layer(n)%sum_lai = 0.0D0 
      enddo

      do n = 1, num_layer

         if ((layer(n)%layer_height .ge. height1).and.&
         &(layer(n-1)%layer_height .lt. height1)) then     
            layer(n)%sum_height=&
            &layer(n)%sum_height + height1
            layer(n)%num_height=&
            &layer(n)%num_height+1
            layer(n)%sum_lai=&    
            &layer(n)%sum_lai + index_leaf
         end if

         layer(n)%mean_height = layer(n)%sum_height/&
         &layer(n)%num_height
         if(layer(n)%sum_height .eq. 0.0D0) then
            layer(n)%mean_height = 0.0D0
         endif
         layer(n)%mean_lai=layer(n)%sum_lai/&
         &layer(n)%num_height
         if(layer(n)%sum_lai .eq. 0.0D0) then
            layer(n)%mean_lai = 0.0D0
         end if
      end do

      ! ======================================================
      !       LIGHT COMPETITION DYNAMIC. [EXTINCTION LIGHT]
      ! ======================================================

      !! INICIALIZE VARIABLES !!
      do n = 1, num_layer
         layer(n)%linc = 0.0D0
         layer(n)%lavai = 0.0D0
         layer(n)%lused = 0.0D0
      enddo
         
      !=================== Beer's Law ========================
      do n = num_layer,1,-1
         layer(n)%beers_law = ipar*&
         &(1-exp(-0.5*layer(n)%mean_lai))
      enddo
      !=======================================================

      ! ======================================================
      !       LIGHT COMPETITION DYNAMIC. [LIGHTS DYNAMIC]
      ! ======================================================

      do n = num_layer,1,-1
         if(n.eq.num_layer) then
            layer(n)%linc = ipar
         else
            if(layer(n)%mean_height.gt.0.0D0) then
               layer(n)%linc = layer(last_with_pls)%lavai
               last_with_pls=n
            else
               continue
            endif
         endif
         layer(n)%lused = layer(n)%linc*(1-exp(-0.5*layer(n)%mean_lai))
         layer(n)%lavai = layer(n)%linc - layer(n)%lused
      enddo

      ! ======================================================
      !    LIGHT COMPET. PHOTOSYNTHESIS PUNISHMENT 
      ! ======================================================

      ! Identifying the layers and allocate each PLS to punishment photosyntesis.

      !! INICIALIZE VARIABLES !!
      do n = 1, num_layer
         layer(n)%layer_id = 0.0D0
         llight = 0.0D0
      enddo

      do n = num_layer, 1, -1
         if (cawood1.eq.0.0D0) then
            aux_ipar = ipar
            llight = ipar
         else
            if (n.eq.num_layer) then 
               layer(n)%layer_id = num_layer
               if (height1.le.max_height.and.height1.gt.layer(n-1)%layer_height) then 
                  llight = ipar
                  aux_ipar = ipar
                  !print*, n, 'LL TOP=', llight, 'aux_ipar', aux_ipar,'ipar', ipar
               endif
            else
               layer(n)%layer_id = layer(n+1)%layer_id-1  
               if (height1.le.layer(n)%layer_height.and.height1.gt.layer(n-1)%layer_height) then
                  llight = (layer(n)%lavai/ipar)
                  aux_ipar = ipar - (ipar*llight) !limitation in % of IPAR total. 
                  !print*, n, 'LL ABOVE % =', llight, 'aux_ipar', aux_ipar !, 'ipar', ipar
               endif
            endif 
         endif  
      enddo

      !============================  END  ========================================================

      if(c4 .eq. 0) then
         !====================-C3 PHOTOSYNTHESIS-===============================
         !Photo-respiration compensation point (Pa)
         mgama = p3/(p8*(p9**(p10*(temp-p11))))
         !Michaelis-Menten CO2 constant (Pa)
         f2 = p12*(p13**(p10*(temp-p11)))
         !Michaelis-Menten O2 constant (Pa)
         f3 = p14*(p15**(p10*(temp-p11)))
         !Saturation vapour pressure (hPa)
         es = real(tetens(temp), r_8)
         !Saturated mixing ratio (kg/kg)
         rmax = 0.622*(es/(p0-es))
         !Moisture deficit at leaf level (kg/kg)
         r = -0.315*rmax
         !Internal leaf CO2 partial pressure (Pa)
         ci = p19* (1.-(r/p20)) * ((c_atm/9.901)-mgama) + mgama
         !Rubisco carboxilation limited photosynthesis rate (molCO2/m2/s)
         jc = vm_in*((ci-mgama)/(ci+(f2*(1.+(p3/f3)))))

         !Light limited photosynthesis rate (molCO2/m2/s)
         ! if (ll) then
         !    aux_ipar = ipar
         ! else
         !    aux_ipar = ipar - (ipar * 0.20)
         ! endif
         
         jl = p4*(1.0-p5)*aux_ipar*((ci-mgama)/(ci+(p6*mgama)))
         amax = jl

         ! Transport limited photosynthesis rate (molCO2/m2/s) (RuBP) (re)generation
         ! ---------------------------------------------------
         je = p7*vm_in

         !Jp (minimum between jc and jl)
         !------------------------------
         b = (-1.)*(jc+jl)
         c = jc*jl
         delta = (b**2)-4.0*a*c
         jp1 = (-b-(sqrt(delta)))/(2.0*a)
         jp2 = (-b+(sqrt(delta)))/(2.0*a)
         jp = dmin1(jp1,jp2)

         !Leaf level gross photosynthesis (minimum between jc, jl and je)
         !---------------------------------------------------------------
         b2 = (-1.)*(jp+je)
         c2 = jp*je
         delta2 = (b2**2)-4.0*a2*c2
         j1 = (-b2-(sqrt(delta2)))/(2.0d0*a2)
         j2 = (-b2+(sqrt(delta2)))/(2.0d0*a2)
         f1a = dmin1(j1,j2)


         f1ab = f1a
         if(f1ab .lt. 0.0D0) f1ab = 0.0D0
         return
      else
         !===========================-C4 PHOTOSYNTHESIS-=============================
         !  USE PHOTO_PAR
         ! ! from Chen et al. 1994
         tk = temp + 273.15           ! K
         t25 = 273.15 + 25.0          ! K
         kp = kp25 * (2.1**(0.1*(tk-t25))) ! ppm

         ! if (ll) then
         !    aux_ipar = ipar
         ! else
         !    aux_ipar = ipar - (ipar * 0.20)
         ! endif

         ipar1 = aux_ipar * 1e6  ! µmol m-2 s-1 - 1e6 converts mol to µmol

         !maximum PEPcarboxylase rate Arrhenius eq. (Dependence on temperature)
         dummy1 = 1.0 + exp((s_vpm * t25 - h_vpm)/(r_vpm * t25))
         dummy2 = 1.0 + exp((s_vpm * tk - h_vpm)/(r_vpm * tk))
         dummy0 = dummy1 / dummy2
         vpm =  vpm25 * exp((-e_vpm/r_vpm) * (1.0/tk - 1.0/t25)) * dummy0

         ! ! actual PEPcarboxylase rate under ipar conditions
         v4m = (alphap * ipar1) / sqrt(1 + alphap**2 * ipar1**2 / vpm**2)

         ! [CO2] mesophyl
         cm0 = 1.674 - 6.1294 * 10.0**(-2) * temp
         cm1 = 1.1688 * 10.0**(-3) * temp ** 2
         cm2 = 8.8741 * 10.0**(-6) * temp ** 3
         cm = 0.7 * c_atm * ((cm0 + cm1 - cm2) / 0.73)

         ! ! When light or PEP carboxylase is limiting
         ! ! FROM CHEN et al. 1994:
         jcl = ((V4m * cm) / (kp + cm)) * 1e-6   ! molCO2 m-2 s-1 / 1e-6 convets µmol 2 mol
         amax = jcl

         ! When V (RuBP regeneration) is limiting
         je = p7 * vm_in

         ! !Leaf level gross photosynthesis (minimum between jcl and je)
         ! !---------------------------------------------------------------
         b2 = (-1.)*(jcl+je)
         c2 = jcl*je
         delta2 = (b2**2)-4.0*a2*c2
         j1 = (-b2-(sqrt(delta2)))/(2.0*a2)
         j2 = (-b2+(sqrt(delta2)))/(2.0*a2)
         f1a = dmin1(j1,j2)


         f1ab = f1a
         if(f1ab .lt. 0.0D0) f1ab = 0.0D0
         return
      endif
   end subroutine photosynthesis_rate

   !=================================================================
   !=================================================================


   subroutine spinup3(nppot,dt,cleafini,cfrootini,cawoodini)
      use types
      implicit none

      !parameters
      integer(kind=i_4),parameter :: ntl=36525

      ! inputs
      integer(kind=i_4) :: kk, k

      real(kind=r_4),intent(in) :: nppot
      real(kind=r_4),dimension(6),intent(in) :: dt
      ! intenal
      real(kind=r_4) :: sensitivity
      real(kind=r_4) :: nppot2
      ! outputs
      real(kind=r_4),intent(out) :: cleafini
      real(kind=r_4),intent(out) :: cawoodini
      real(kind=r_4),intent(out) :: cfrootini

      ! more internal
      real(kind=r_4),dimension(ntl) :: cleafi_aux
      real(kind=r_4),dimension(ntl) :: cfrooti_aux
      real(kind=r_4),dimension(ntl) :: cawoodi_aux

      real(kind=r_4) :: aux_leaf
      real(kind=r_4) :: aux_wood
      real(kind=r_4) :: aux_root
      real(kind=r_4) :: out_leaf
      real(kind=r_4) :: out_wood
      real(kind=r_4) :: out_root

      real(kind=r_4) :: aleaf  !npp percentage alocated to leaf compartment
      real(kind=r_4) :: aawood !npp percentage alocated to aboveground woody biomass compartment
      real(kind=r_4) :: afroot !npp percentage alocated to fine roots compartmentc
      real(kind=r_4) :: tleaf  !turnover time of the leaf compartment (yr)
      real(kind=r_4) :: tawood !turnover time of the aboveground woody biomass compartment (yr)
      real(kind=r_4) :: tfroot !turnover time of the fine roots compartment
      logical(kind=l_1) :: iswoody

      ! catch 'C turnover' traits
      tleaf  = dt(1)
      tawood = dt(2)
      tfroot = dt(3)
      aleaf  = dt(4)
      aawood = dt(5)
      afroot = dt(6)

      iswoody = aawood .gt. 0.0

      sensitivity = 1.001
      if(nppot .le. 0.0) goto 200
      nppot2 = nppot !/real(npls,kind=r_4)
      do k=1,ntl
         if (k.eq.1) then
            cleafi_aux (k) =  aleaf * nppot2
            cawoodi_aux(k) = aawood * nppot2
            cfrooti_aux(k) = afroot * nppot2
         else
            aux_leaf = cleafi_aux(k-1) + (aleaf * nppot2)
            aux_wood = cawoodi_aux(k-1) + (aleaf * nppot2)
            aux_root = cfrooti_aux(k-1) + (afroot * nppot2)

            out_leaf = aux_leaf - (cleafi_aux(k-1) / tleaf)
            out_wood = aux_wood - (cawoodi_aux(k-1) / tawood)
            out_root = aux_root - (cfrooti_aux(k-1) / tfroot)

            if(iswoody) then
               cleafi_aux(k) = amax1(0.0, out_leaf)
               cawoodi_aux(k) = amax1(0.0, out_wood)
               cfrooti_aux(k) = amax1(0.0, out_root)
            else
               cleafi_aux(k) = amax1(0.0, out_leaf)
               cfrooti_aux(k) = amax1(0.0, out_root)
               cawoodi_aux(k) = 0.0
            endif

            kk =  floor(k*0.66)
            if(iswoody) then
               if((cfrooti_aux(k)/cfrooti_aux(kk).lt.sensitivity).and.&
                    &(cleafi_aux(k)/cleafi_aux(kk).lt.sensitivity).and.&
                    &(cawoodi_aux(k)/cawoodi_aux(kk).lt.sensitivity)) then

                  cleafini = cleafi_aux(k) ! carbon content (kg m-2)
                  cfrootini = cfrooti_aux(k)
                  cawoodini = cawoodi_aux(k)
                  !  print *, 'woody exitet in', k
                  exit
               endif
            else
               if((cfrooti_aux(k)&
                    &/cfrooti_aux(kk).lt.sensitivity).and.&
                    &(cleafi_aux(k)/cleafi_aux(kk).lt.sensitivity)) then

                  cleafini = cleafi_aux(k) ! carbon content (kg m-2)
                  cfrootini = cfrooti_aux(k)
                  cawoodini = 0.0
                  !  print *, 'grass exitet in', k
                  exit
               endif
            endif
         endif
      enddo                  !nt
200   continue
   end subroutine spinup3

   ! ===========================================================
   ! ===========================================================

   subroutine spinup2(nppot,dt,cleafini,cfrootini,cawoodini)
      use types
      use global_par, only: ntraits,npls
      implicit none

      !parameters
      integer(kind=i_4),parameter :: ntl=36525

      ! inputs
      integer(kind=i_4) :: i6, kk, k

      real(kind=r_4),intent(in) :: nppot
      real(kind=r_4),dimension(ntraits, npls),intent(in) :: dt
      ! intenal
      real(kind=r_4) :: sensitivity
      real(kind=r_4) :: nppot2
      ! outputs
      real(kind=r_4),dimension(npls),intent(out) :: cleafini
      real(kind=r_4),dimension(npls),intent(out) :: cfrootini
      real(kind=r_4),dimension(npls),intent(out) :: cawoodini

      ! more internal
      real(kind=r_4),dimension(ntl) :: cleafi_aux
      real(kind=r_4),dimension(ntl) :: cfrooti_aux
      real(kind=r_4),dimension(ntl) :: cawoodi_aux

      real(kind=r_4) :: aux_leaf
      real(kind=r_4) :: aux_wood
      real(kind=r_4) :: aux_root
      real(kind=r_4) :: out_leaf
      real(kind=r_4) :: out_wood
      real(kind=r_4) :: out_root

      real(kind=r_4),dimension(npls) :: aleaf  !npp percentage alocated to leaf compartment
      real(kind=r_4),dimension(npls) :: aawood !npp percentage alocated to aboveground woody biomass compartment
      real(kind=r_4),dimension(npls) :: afroot !npp percentage alocated to fine roots compartmentc
      real(kind=r_4),dimension(npls) :: tleaf  !turnover time of the leaf compartment (yr)
      real(kind=r_4),dimension(npls) :: tawood !turnover time of the aboveground woody biomass compartment (yr)
      real(kind=r_4),dimension(npls) :: tfroot !turnover time of the fine roots compartment
      logical(kind=l_1) :: iswoody

      ! catch 'C turnover' traits
      tleaf  = dt(3,:)
      tawood = dt(4,:)
      tfroot = dt(5,:)
      aleaf  = dt(6,:)
      aawood = dt(7,:)
      afroot = dt(8,:)

      sensitivity = 1.01
      if(nppot .le. 0.0) goto 200
      nppot2 = nppot !/real(npls,kind=r_4)
      do i6=1,npls
         iswoody = ((aawood(i6) .gt. 0.0) .and. (tawood(i6) .gt. 0.0))
         do k=1,ntl
            if (k .eq. 1) then
               cleafi_aux (k) =  aleaf(i6) * nppot2
               cawoodi_aux(k) = aawood(i6) * nppot2
               cfrooti_aux(k) = afroot(i6) * nppot2

            else
               aux_leaf = cleafi_aux(k-1) + (aleaf(i6) * nppot2)
               aux_wood = cawoodi_aux(k-1) + (aleaf(i6) * nppot2)
               aux_root = cfrooti_aux(k-1) + (afroot(i6) * nppot2)

               out_leaf = aux_leaf - (cleafi_aux(k-1) / tleaf(i6))
               out_wood = aux_wood - (cawoodi_aux(k-1) / tawood(i6))
               out_root = aux_root - (cfrooti_aux(k-1) / tfroot(i6))

               if(iswoody) then
                  cleafi_aux(k) = amax1(0.0, out_leaf)
                  cawoodi_aux(k) = amax1(0.0, out_wood)
                  cfrooti_aux(k) = amax1(0.0, out_root)
               else
                  cleafi_aux(k) = amax1(0.0, out_leaf)
                  cawoodi_aux(k) = 0.0
                  cfrooti_aux(k) = amax1(0.0, out_root)
               endif

               kk =  floor(k*0.66)
               if(iswoody) then
                  if((cfrooti_aux(k)/cfrooti_aux(kk).lt.sensitivity).and.&
                       &(cleafi_aux(k)/cleafi_aux(kk).lt.sensitivity).and.&
                       &(cawoodi_aux(k)/cawoodi_aux(kk).lt.sensitivity)) then

                     cleafini(i6) = cleafi_aux(k) ! carbon content (kg m-2)
                     cfrootini(i6) = cfrooti_aux(k)
                     cawoodini(i6) = cawoodi_aux(k)
                     exit
                  endif
               else
                  if((cfrooti_aux(k)&
                       &/cfrooti_aux(kk).lt.sensitivity).and.&
                       &(cleafi_aux(k)/cleafi_aux(kk).lt.sensitivity)) then

                     cleafini(i6) = cleafi_aux(k) ! carbon content (kg m-2)
                     cfrootini(i6) = cfrooti_aux(k)
                     cawoodini(i6) = 0.0
                     exit
                  endif
               endif
            endif
         enddo                  !nt
      enddo                     !npls
200   continue
   end subroutine spinup2

  !===================================================================
  !===================================================================

   function m_resp(temp, ts,cl1_mr,cf1_mr,ca1_mr,&
        & n2cl,n2cw,n2cf,aawood_mr) result(rm)

      use types, only: r_4,r_8
      use global_par, only: sapwood
      !implicit none

      real(r_4), intent(in) :: temp, ts
      real(r_8), intent(in) :: cl1_mr
      real(r_8), intent(in) :: cf1_mr
      real(r_8), intent(in) :: ca1_mr
      real(r_8), intent(in) :: n2cl
      real(r_8), intent(in) :: n2cw
      real(r_8), intent(in) :: n2cf
      real(r_8), intent(in) :: aawood_mr
      real(r_4) :: rm

      real(r_8) :: csa, rm64, rml64
      real(r_8) :: rmf64, rms64
      real(r_8), parameter :: a1 = 25.0D0, a2 = 0.04D0
      !   Autothrophic respiration
      !   ========================
      !   Maintenance respiration (kgC/m2/yr) (based in Ryan 1991)

      ! sapwood carbon content (kgC/m2). X% of woody tissues (Pavlick, 2013)
      ! only for woody PLSs
      if(aawood_mr .gt. 0.0) then
         csa = sapwood * ca1_mr
         rms64 = ((n2cw * (csa * 1D3)) * a1 * dexp(a2 * temp))
      else
         rms64 = 0.0
      endif

      rml64 = ((n2cl * (cl1_mr * 1D3)) * a1 * dexp(a2 * temp))

      rmf64 = ((n2cf * (cf1_mr * 1D3)) * a1 * dexp(a2 * ts))

      rm64 = (rml64 + rmf64 + rms64) * 1D-3

      rm = real(rm64,r_4)

      if (rm .lt. 0) then
         rm = 0.0
      endif

   end function m_resp


  !===================================================================
  !===================================================================

   function sto_resp(temp, sto_mr) result(rm)
    use types, only: r_4,r_8
    !implicit none

      real(r_4), intent(in) :: temp
      real(r_8), dimension(3), intent(in) :: sto_mr
      real(r_8) :: rm

      real(r_8) :: stoc,ston
      real(r_8), parameter :: a1 = 25.0D0, a2 = 0.04D0

    !   Autothrophic respiration
    !   ========================

    stoc = sto_mr(1)
    ston = sto_mr(2)
   !  print*, ston

    if(stoc .le. 0.0D0) then
       rm = 0.0D0
       return
    endif

    if(ston .lt. 0.0D0) then
      ston = 1.0D0/300.0D0
    else
      ston = ston/stoc
    endif

    rm = ((ston * stoc) * a1 * dexp(a2 * temp))

    if (rm .lt. 0) then
       rm = 0.0
    endif
    return


 end function sto_resp


   !====================================================================
   !====================================================================

   function g_resp(beta_leaf,beta_awood, beta_froot,aawood_rg) result(rg)
      use types, only: r_4,r_8
      !implicit none

      real(r_8), intent(in) :: beta_leaf
      real(r_8), intent(in) :: beta_froot
      real(r_8), intent(in) :: beta_awood
      real(r_8), intent(in) :: aawood_rg
      real(r_4) :: rg

      real(r_8) :: rg64, rgl64, rgf64, rgs64
      real(r_8) :: a1,a2,a3

      !     Autothrophic respiration
      !     Growth respiration (KgC/m2/yr)(based in Ryan 1991; Sitch et al.
      !     2003; Levis et al. 2004)

      a1 = beta_leaf
      a2 = beta_froot
      a3 = beta_awood

      if(a1 .le. 0.0D0) a1 = 0.0D0
      if(a2 .le. 0.0D0) a2 = 0.0D0
      if(a3 .le. 0.0D0) a3 = 0.0D0

      rgl64 = 1.25D0 * a1
      rgf64 = 1.25D0 * a2

      if(aawood_rg .gt. 0.0D0) then
         rgs64 = 1.25D0 * a3
      else
         rgs64 = 0.0D0
      endif

      rg64 = rgl64 + rgf64 + rgs64

      rg = real(rg64,r_4)

      if (rg.lt.0) then
         rg = 0.0
      endif

   end function g_resp

   !====================================================================
   !====================================================================

   function tetens(t) result(es)
      ! returns Saturation Vapor Pressure (hPa), using Buck equation

      ! buck equation...references:
      ! http://www.hygrometers.com/wp-content/uploads/CR-1A-users-manual-2009-12.pdf
      ! Hartmann 1994 - Global Physical Climatology p.351
      ! https://en.wikipedia.org/wiki/Arden_Buck_equation#CITEREFBuck1996

      ! Buck AL (1981) New Equations for Computing Vapor Pressure and Enhancement Factor.
      !      J. Appl. Meteorol. 20:1527–1532.

      use types, only: r_4
      !implicit none

      real(r_4),intent( in) :: t
      real(r_4) :: es

      if (t .ge. 0.) then
         es = 6.1121 * exp((18.729-(t/227.5))*(t/(257.87+t))) ! Arden Buck
         !es = es * 10 ! transform kPa in mbar == hPa
         return
      else
         es = 6.1115 * exp((23.036-(t/333.7))*(t/(279.82+t))) ! Arden Buck
         !es = es * 10 ! mbar == hPa ! mbar == hPa
         return
      endif

   end function tetens

   !====================================================================
   !====================================================================

   subroutine pft_area_frac(cleaf1, cfroot1, cawood1, awood,&
                          & ocp_coeffs, ocp_wood, run_pls, c_to_soil)
      use types, only: l_1, i_4, r_8
      use global_par, only: npls, cmin, sapwood
      !implicit none

      integer(kind=i_4),parameter :: npft = npls ! plss futuramente serao

      real(kind=r_8),dimension(npft),intent( in) :: cleaf1, cfroot1, cawood1, awood
      real(kind=r_8),dimension(npft),intent(out) :: ocp_coeffs
      logical(kind=l_1),dimension(npft),intent(out) :: ocp_wood
      integer(kind=i_4),dimension(npft),intent(out) :: run_pls
      real(kind=r_8), dimension(npls), intent(out) :: c_to_soil ! NOT IMPLEMENTED IN BUDGET
      logical(kind=l_1),dimension(npft) :: is_living
      real(kind=r_8),dimension(npft) :: cleaf, cawood, cfroot
      real(kind=r_8),dimension(npft) :: total_biomass_pft,total_w_pft
      integer(kind=i_4) :: p,i
      integer(kind=i_4),dimension(1) :: max_index
      real(kind=r_8) :: total_biomass, total_wood
      integer(kind=i_4) :: five_percent

      total_biomass = 0.0D0
      total_wood = 0.0D0

      cleaf = cleaf1
      cfroot = cfroot1
      cawood = cawood1

      do p = 1, npft
         if(awood(p) .le. 0.0D0) then
            cawood(p) = 0.0D0
         endif
      enddo


      do p = 1,npft
         total_w_pft(p) = 0.0D0
         total_biomass_pft(p) = 0.0D0
         ocp_coeffs(p) = 0.0D0
         ocp_wood(p) = .false.
      enddo

      ! check for nan in cleaf cawood cfroot
      do p = 1,npft
         if(isnan(cleaf(p))) cleaf(p) = 0.0D0
         if(isnan(cfroot(p))) cfroot(p) = 0.0D0
         if(isnan(cawood(p))) cawood(p) = 0.0D0
      enddo

      do p = 1,npft
         if(cleaf(p) .lt. cmin .and. cfroot(p) .lt. cmin) then
            is_living(p) = .false.
            c_to_soil(p) = cleaf(p) + cawood(p) + cfroot(p)
            cleaf(p) = 0.0D0
            cawood(p) = 0.0D0
            cfroot(p) = 0.0D0
         else
            is_living(p) = .true.
            c_to_soil(p) = 0.0D0
         endif
      enddo

      do p = 1,npft
         ! total_biomass_pft(p) = cleaf(p) + cfroot(p) + (sapwood * cawood(p)) ! only sapwood?
         total_biomass_pft(p) = cleaf(p) + cfroot(p) + cawood(p)
         total_biomass = total_biomass + total_biomass_pft(p)
         total_wood = total_wood + cawood(p)
         total_w_pft(p) = cawood(p)
      enddo

      !     grid cell occupation coefficients
      if(total_biomass .gt. 0.0D0) then
         do p = 1,npft
            ocp_coeffs(p) = total_biomass_pft(p) / total_biomass
            if(ocp_coeffs(p) .lt. 0.0D0) ocp_coeffs(p) = 0.0D0

            if(ocp_coeffs(p) .gt. 0.0D0 .and. is_living(p)) then
               run_pls(p) = 1
            else
               run_pls(p) = 0
            endif
            !if(isnan(ocp_coeffs(p))) ocp_coeffs(p) = 0.0
         enddo
      else
         do p = 1,npft
            ocp_coeffs(p) = 0.0D0
            run_pls(p) = 0
         enddo
      endif

      !     gridcell pft ligth limitation by wood content
      five_percent = nint(real(npft) * 0.05)
      if(five_percent .eq. 0) five_percent = 1
      if(five_percent .eq. 1) then
         if(total_wood .gt. 0.0) then
            max_index = maxloc(total_w_pft)
            i = max_index(1)
            ocp_wood(i) = .true.
         endif
      else
         do p = 1,five_percent
            if(total_wood .gt. 0.0D0) then
               max_index = maxloc(total_w_pft)
               i = max_index(1)
               total_w_pft(i) = 0.0D0
               ocp_wood(i) = .true.
            endif
         enddo
      endif

   end subroutine pft_area_frac

   !====================================================================
   !====================================================================

   subroutine pls_allometry (dt,cawood1,awood,height,diameter,&
      &crown_area)
      !Based in LPJ model (Smith et al., 2001; Sitch et al., 2003)

      use types 
      use global_par
      use allometry_par

      integer(i_4),parameter :: npft = npls 
      integer(i_4) :: p
      real(r_8),dimension(ntraits, npls),intent(in) :: dt
      real(r_8),dimension(npft),intent(in) :: cawood1, awood
      real(r_8),dimension(npft),intent(out) :: height, diameter, crown_area !fpc_ind, fpc_grid
      real(r_8),dimension(npft) :: cawood, dwood, crown_area_max
      !5 = número de individuos arbitrário

      
      ! ============================
      dwood = dt(18,:)
      cawood = (cawood1/5)
      crown_area_max = 30.0 !m2 !number from lplmfire code (establishment.f90)
      ! ============================
    
      do p = 1, npft !INICIALIZE OUTPUTS VARIABLES
         height(p) = 0.0D0
         diameter(p) = 0.0D0
         crown_area(p) = 0.0D0
      enddo

      !PLS DIAMETER (in m.)
      do p = 1, npft !to grasses
         if(awood(p) .le. 0.0D0) then
            height(p) = 0.0D0 !in m.
            diameter(p) = 0.0D0 !in m.
            crown_area(p) = 0.0D0 !in m2.
            dwood(p) = 0.0D0
         else
            diameter(p) = (4*(cawood(p)*1.0D3)/(dwood(p)*1.0D6)*pi*k_allom2)&
            &**(1/(2+k_allom3))
            height(p) = k_allom2*(diameter(p)**k_allom3)
            crown_area(p) = min(crown_area_max(p), k_allom1*(diameter(p)**krp))
         endif
      enddo
      
   end subroutine pls_allometry

   subroutine se_module (cleaf, cwood, cfroot, awood, csoil, litter_leaf, litter_fr,&
      & cwd, co2_abs)

      use types 
      use global_par

      real(r_8), intent(in) :: awood
      real(r_8), intent(in) :: cleaf, cwood, cfroot, csoil
      real(r_8), intent(in) :: litter_leaf, litter_fr, cwd
      real(r_8) :: biomass, carbon_soil !internal variable
      real(r_8) :: om, cwd1 !om = Organic Mat. (leaf and fine root litter) / cwd = coarse wood debries
      real(r_8) :: co2_abs

      !CO2_abs - Quantidade de CO2 absorvido (sequestrado) e estocado 
      !nos tecidos vegetais (caule, folha e raízes), no solo e na serrapilheira. 
      !SE de regulação climática - Service flow indicators (Burkhard et al., 2014)
      !Unidade: tCO2/ha/ano
      !*3,67 -> equivale ao peso molecular do CO2 determinado pela proporção de CO2 para C;
      !Para cada tonelada de C fixado na fitomassa, corresponde o equivalente a uma mitigação 
      !de 3,67 t de CO2 da atmosfera (Yu, 2004; Nishi et al., 2005).
      !Este valor é estimado dividindo o peso molecular do CO2 (44u - C: 12u; O2: 32u)
      !pelo peso molecular do C (12u). Ou seja, 44/12 = 3,67.
      !Outras refs: https://www.ecomatcher.com/how-to-calculate-co2-sequestration/
      !#:~:text=The%20atomic%20weight%20of%20Carbon,in%20the%20tree%20by%203.67. 

      carbon_soil = (csoil/1.0D3) !transfor to g/m2 to kg/m2
      om = ((litter_leaf + litter_fr)/1.0D3) !transfor to g/m2 to kg/m2
      cwd1 = (cwd/1.0D3) !transfor to g/m2 to kg/m2

      if (awood .le. 0.0D0) then
         biomass = (cleaf + cfroot + carbon_soil + om) !transfor kgC/m² -> t/ha in BUDGET.f90
         co2_abs = (biomass*3.67) !CO2 absorvido em t/ha
      else
         biomass = (cleaf + cwood + cfroot + carbon_soil + om + cwd1) !transfor kgC/m² -> t/ha in BUDGET.f90
         co2_abs = (biomass*3.67) !CO2 absorvido em t/ha
      endif


   end subroutine se_module

end module photo


module water

  ! this module defines functions related to surface water balance
  implicit none
  private

  ! functions defined here:

  public ::              &
       wtt              ,&
       soil_temp        ,&
       soil_temp_sub    ,&
       penman           ,&
       evpot2           ,&
       available_energy ,&
       runoff


contains

   !====================================================================
   !====================================================================

function wtt(t) result(es)
   ! returns Saturation Vapor Pressure (hPa), using Buck equation

   ! buck equation...references:
   ! http://www.hygrometers.com/wp-content/uploads/CR-1A-users-manual-2009-12.pdf
   ! Hartmann 1994 - Global Physical Climatology p.351
   ! https://en.wikipedia.org/wiki/Arden_Buck_equation#CITEREFBuck1996

   ! Buck AL (1981) New Equations for Computing Vapor Pressure and Enhancement Factor.
   !      J. Appl. Meteorol. 20:1527–1532.

   use types, only: r_4
   !implicit none

   real(r_4),intent( in) :: t
   real(r_4) :: es

   if (t .ge. 0.) then
      es = 6.1121 * exp((18.729-(t/227.5))*(t/(257.87+t))) ! Arden Buck
      !es = es * 10 ! transform kPa in mbar == hPa
      return
   else
      es = 6.1115 * exp((23.036-(t/333.7))*(t/(279.82+t))) ! Arden Buck
      !es = es * 10 ! mbar == hPa ! mbar == hPa
      return
   endif

end function wtt

!====================================================================
!====================================================================

  !=================================================================
  !=================================================================

  subroutine soil_temp_sub(temp, tsoil)
  ! Calcula a temperatura do solo. Aqui vamos mudar no futuro!
  ! a tsoil deve ter relacao com a et realizada...
  ! a profundidade do solo (H) e o coef de difusao (DIFFU) devem ser
  ! variaveis (MAPA DE SOLO?; agua no solo?)
  use types
  use global_par
  !implicit none
  integer(i_4),parameter :: m = 1095

  real(r_4),dimension(m), intent( in) :: temp ! future __ make temps an allocatable array
  real(r_4), intent(out) :: tsoil

  ! internal vars

  integer(i_4) :: n, k
  real(r_4) :: t0 = 0.0
  real(r_4) :: t1 = 0.0

  tsoil = -9999.0

  do n=1,m !run to attain equilibrium
     k = mod(n,12)
     if (k.eq.0) k = 12
     t1 = (t0*exp(-1.0/tau) + (1.0 - exp(-1.0/tau)))*temp(k)
     tsoil = (t0 + t1)/2.0
     t0 = t1
  enddo
  end subroutine soil_temp_sub

  !=================================================================
  !=================================================================

  function soil_temp(t0,temp) result(tsoil)
    use types
    use global_par, only: h, tau, diffu
    !implicit none

    real(r_4),intent( in) :: temp
    real(r_4),intent( in) :: t0
    real(r_4) :: tsoil

    real(r_4) :: t1 = 0.0

    t1 = (t0*exp(-1.0/tau) + (1.0 - exp(-1.0/tau)))*temp
    tsoil = (t0 + t1)/2.0
  end function soil_temp

  !=================================================================
  !=================================================================

  function penman (spre,temp,ur,rn,rc2) result(evap)
    use types, only: r_4
    use global_par, only: rcmin, rcmax
    !implicit none


    real(r_4),intent(in) :: spre                 !Surface pressure (mbar)
    real(r_4),intent(in) :: temp                 !Temperature (°C)
    real(r_4),intent(in) :: ur                   !Relative humidity (0-1)
    real(r_4),intent(in) :: rn                   !Radiation balance (W/m2)
    real(r_4),intent(in) :: rc2                  !Canopy resistence (s/m)

    real(r_4) :: evap                            !Evapotranspiration (mm/day)
    !     Parameters
    !     ----------
    real(r_4) :: ra, h5, t1, t2, es, es1, es2, delta_e, delta
    real(r_4) :: gama, gama2


    ra = rcmin
    h5 = 0.0275               !mb-1

    !     Delta
    !     -----
    t1 = temp + 1.
    t2 = temp - 1.
    es1 = wtt(t1)       !Saturation partial pressure of water vapour at temperature T
    es2 = wtt(t2)

    delta = (es1-es2)/(t1-t2) !mbar/oC
    !
    !     Delta_e
    !     -------
    es = wtt (temp)
    delta_e = es*(1. - ur)    !mbar

   if ((delta_e.ge.(1./h5)-0.5).or.(rc2.ge.rcmax)) evap = 0.
   if ((delta_e.lt.(1./h5)-0.5).or.(rc2.lt.rcmax)) then
      !     Gama and gama2
      !     --------------
      gama  = spre*(1004.)/(2.45e6*0.622)
      gama2 = gama*(ra + rc2)/ra

      !     Real evapotranspiration
      !     -----------------------
      ! LH
      evap = (delta* rn + (1.20*1004./ra)*delta_e)/(delta+gama2) !W/m2
      ! H2O MASS
      evap = evap*(86400./2.45e6) !mm/day
      evap = amax1(evap,0.)  !Eliminates condensation
   endif
  end function penman

  !=================================================================
  !=================================================================

  function available_energy(temp) result(ae)
    use types, only: r_4
    !implicit none

    real(r_4),intent(in) :: temp
    real(r_4) :: ae

    ae = 2.895 * temp + 52.326 !from NCEP-NCAR Reanalysis data
  end function  available_energy

  !=================================================================
  !=================================================================

  function runoff(wa) result(roff)
    use types, only: r_4
    !implicit none

    real(r_4),intent(in) :: wa
    real(r_4):: roff

    !  roff = 38.*((w/wmax)**11.) ! [Eq. 10]
    roff = 11.5*((wa)**6.6) !from NCEP-NCAR Reanalysis data
  end function  runoff

  !=================================================================
  !=================================================================

  function evpot2 (spre,temp,ur,rn) result(evap)
    use types, only: r_4
    use global_par, only: rcmin, rcmax
    !implicit none

    !Commments from CPTEC-PVM2 code
!    c Entradas
!c --------
!c spre   = pressao aa supeficie (mb)
!c temp   = temperatura (oC)
!c ur     = umidade relativa  (0-1,adimensional)
!c rn     = saldo de radiacao (W m-2)
!c
!c Saida
!c -----
!c evap  = evapotranspiracao potencial sem estresse (mm/dia)

    !     Inputs

    real(r_4),intent(in) :: spre                 !Surface pressure (mb)
    real(r_4),intent(in) :: temp                 !Temperature (oC)
    real(r_4),intent(in) :: ur                   !Relative humidity (0-1,dimensionless)
    real(r_4),intent(in) :: rn                   !Radiation balance (W/m2)
    !     Output
    !     ------
    !
    real(r_4) :: evap                 !Evapotranspiration (mm/day)
    !     Parameters
    !     ----------
    real(r_4) :: ra, t1, t2, es, es1, es2, delta_e, delta
    real(r_4) :: gama, gama2, rc

    ra = rcmin            !s/m

    !     Delta

    t1 = temp + 1.
    t2 = temp - 1.
    es1 = wtt(t1)
    es2 = wtt(t2)
    delta = (es1-es2)/(t1-t2) !mb/oC

    !     Delta_e
    !     -------

    es = wtt (temp)
    delta_e = es*(1. - ur)    !mb

    !     Stomatal Conductance
    !     --------------------

    rc = rcmin

    !     Gama and gama2
    !     --------------

    gama  = spre*(1004.)/(2.45e6*0.622)
    gama2 = gama*(ra + rc)/ra

    !     Potencial evapotranspiration (without stress)
    !     ---------------------------------------------

    evap =(delta*rn + (1.20*1004./ra)*delta_e)/(delta+gama2) !W/m2
    evap = evap*(86400./2.45e6) !mm/day
    evap = amax1(evap,0.)     !Eliminates condensation
  end function evpot2

  !=================================================================
  !=================================================================

end module water
