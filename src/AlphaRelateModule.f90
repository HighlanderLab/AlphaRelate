
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

!###############################################################################

!-------------------------------------------------------------------------------
! The Roslin Institute, The University of Edinburgh - AlphaGenes Group
!-------------------------------------------------------------------------------
!
!> @file     AlphaRelateModule.f90
!
! DESCRIPTION:
!> @brief    Relationships
!
!> @details  Calculate relationships among individuals from different sources, i.e.,
!!           pedigree, marker genotypes, or haplotypes.
!
!> @author   Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
!
!> @date     December 19, 2016
!
!> @version  0.0.1 (alpha)
!
! REVISION HISTORY:
! 2016-12-19 GGorjanc - Initial setup as portable/documented module
!
!-------------------------------------------------------------------------------
module AlphaRelateModule
  use ISO_Fortran_env, STDIN => input_unit, STDOUT => output_unit, STDERR => error_unit
  use ConstantModule, only : FILELENGTH, SPECOPTIONLENGTH, IDLENGTH
  use AlphaHouseMod, only : CountLines, Char2Int, Char2Double, Int2Char, Real2Char, ParseToFirstWhitespace,&
                            SplitLineIntoTwoParts, ToLower
  use PedigreeModule, only : PedigreeHolder, RecodedPedigreeArray, MakeRecodedPedigreeArray

  implicit none

  ! integer(int32) :: AllFreqSelCycle
  ! integer(int32) :: nGMat, GlobalExtraAnimals, OldAMatNInd
  ! integer(int32) :: NRMmem, shell, shellmax, shellWarning
  ! integer(int32),allocatable :: seqid(:),seqsire(:),seqdam(:),seqoutput(:)
  ! integer(int32),allocatable :: RecodeGenotypeId(:),passedorder(:),dooutput(:)
  ! integer(int32),allocatable :: OldAMatId(:)

  ! real(real64),allocatable :: Adiag(:)
  ! real(real64),allocatable :: tZMat(:,:),AMat(:,:),InvAMat(:,:)
  ! real(real64),allocatable :: GMat(:,:,:),InvGMat(:,:,:)

  private
  ! Types
  public :: AlphaRelateTitle, AlphaRelateSpec, AlphaRelateData
  ! Methods
  public :: PedInbreeding

  !> @brief AlphaRelate specifications
  type AlphaRelateSpec
    character(len=FILELENGTH) :: SpecFile, PedigreeFile, GenotypeFile, HaplotypeFile
    character(len=FILELENGTH) :: LocusWeightFile, AlleleFreqFile, OldPedNrmFile
    character(len=SPECOPTIONLENGTH) :: GenNrmType, OutputFormat

    logical :: SpecPresent, PedigreePresent, GenotypePresent, HaplotypePresent
    logical :: LocusWeightPresent, AlleleFreqPresent, AlleleFreqFixed, OldPedNrmPresent

    logical :: PedInbreeding, PedNrm, PedNrmMat, PedNrmIja, PedNrmInv, PedNrmInvMat, PedNrmInvIja
    logical :: GenInbreeding, GenNrm, GenNrmMat, GenNrmIja, GenNrmInv, GenNrmInvMat, GenNrmInvIja
    logical :: HapInbreeding, HapNrm, HapNrmMat, HapNrmIja, HapNrmInv, HapNrmInvMat, HapNrmInvIja
    logical :: FudgeGenNrmDiag, BlendGenNrm, FudgeHapNrmDiag, BlendHapNrm

    integer(int32):: nTrait, nGenMat, nLocus, OldPedNrmNInd

    real(real64):: AlleleFreqAll
    real(real64):: FudgeGenNrmDiagFactor, BlendGenNrmFactor, FudgeHapNrmDiagFactor, BlendHapNrmFactor
  end type

  interface AlphaRelateSpec
    module procedure InitAlphaRelateSpec
  end interface AlphaRelateSpec

  !> @brief AlphaRelate data
  type AlphaRelateData
    integer(int32) :: nIndPed
    type(RecodedPedigreeArray) :: RecPed
    real(real64), allocatable :: PedInbreeding(:)
    real(real64), allocatable :: PedNrm(:,:)
    real(real64), allocatable :: PedNrmInv(:,:)

    !character(len=IDLENGTH), allocatable :: IdGeno(:)

    !integer(int32):: nAnisRawPedigree, nAnisP, nAnisG, nAnisH, nLocus, nTrait
    !integer(int32), allocatable :: MapAnimal(:)

    !real(real64), allocatable :: AlleleFreq(:)
    !real(real64), allocatable :: Genos(:,:), ZMat(:,:), LocusWeight(:,:)

    !logical, allocatable :: MapToG(:), AnimalsInBoth(:)
    contains
      procedure :: Destroy => DestroyAlphaRelateData
      procedure :: CalcPedInbreeding
      procedure :: WritePedInbreeding
      procedure :: CalcPedNrm
      !procedure :: WritePedNrm
      !procedure :: CalcPedNrmInv
      !procedure :: WritePedNrmInv
  end type

  interface AlphaRelateData
    module procedure InitAlphaRelateData
  end interface AlphaRelateData

  contains

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   AlphaRelateSpec constructor
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    function InitAlphaRelateSpec(SpecFile) result(Spec)
      implicit none

      ! Arguments
      character(len=*), optional :: SpecFile !< Spec file; when missing, a stub with defaults is created
      type(AlphaRelateSpec) :: Spec          !< @return Specifications

      ! Other
      character(len=:), allocatable :: DumString
      character(len=SPECOPTIONLENGTH) :: Line
      character(len=SPECOPTIONLENGTH) :: First
      character(len=SPECOPTIONLENGTH), dimension(:), allocatable :: Second

      integer(int32) :: SpecUnit, Stat, nTmp, i

      ! Defaults
      Spec%SpecFile        = "None"
      Spec%PedigreeFile    = "None"
      Spec%GenotypeFile    = "None"
      Spec%HaplotypeFile   = "None"
      Spec%LocusWeightFile = "None"
      Spec%AlleleFreqFile  = "None"
      Spec%OldPedNrmFile   = "None"

      Spec%GenNrmType   = "None"
      Spec%OutputFormat = "f20.16"

      Spec%SpecPresent        = .false.
      Spec%PedigreePresent    = .false.
      Spec%GenotypePresent    = .false.
      Spec%HaplotypePresent   = .false.
      Spec%LocusWeightPresent = .false.
      Spec%AlleleFreqPresent  = .false.
      Spec%AlleleFreqFixed    = .false.
      Spec%OldPedNrmPresent   = .false.

      Spec%PedInbreeding      = .false.
      Spec%PedNrm             = .false.
      Spec%PedNrmMat          = .false.
      Spec%PedNrmIja          = .false.
      Spec%PedNrmInv          = .false.
      Spec%PedNrmInvMat       = .false.
      Spec%PedNrmInvIja       = .false.

      Spec%GenInbreeding      = .false.
      Spec%GenNrm             = .false.
      Spec%GenNrmMat          = .false.
      Spec%GenNrmIja          = .false.
      Spec%GenNrmInv          = .false.
      Spec%GenNrmInvMat       = .false.
      Spec%GenNrmInvIja       = .false.
      Spec%FudgeGenNrmDiag    = .false.
      Spec%BlendGenNrm        = .false.

      Spec%HapInbreeding      = .false.
      Spec%HapNrm             = .false.
      Spec%HapNrmMat          = .false.
      Spec%HapNrmIja          = .false.
      Spec%HapNrmInv          = .false.
      Spec%HapNrmInvMat       = .false.
      Spec%HapNrmInvIja       = .false.
      Spec%FudgeHapNrmDiag    = .false.
      Spec%BlendHapNrm        = .false.

      Spec%nTrait        = 1
      Spec%nGenMat       = 0
      Spec%nLocus        = 0
      Spec%OldPedNrmNInd = 0

      Spec%AlleleFreqAll         = 0.5d0
      Spec%FudgeHapNrmDiagFactor = 0.0d0
      Spec%BlendHapNrmFactor     = 0.0d0
      Spec%FudgeHapNrmDiagFactor = 0.0d0
      Spec%BlendHapNrmFactor     = 0.0d0

      if (present(SpecFile)) then

        Spec%SpecPresent = .true.
        Spec%SpecFile = SpecFile
        open(newunit=SpecUnit, file=trim(Spec%SpecFile), action="read", status="old")

        Stat = 0
        ReadSpec: do while (Stat == 0)
          read(SpecUnit, "(a)", iostat=Stat) Line
          if (len_trim(Line) == 0) then
            cycle
          end if

          call SplitLineIntoTwoParts(trim(Line), First, Second)

          DumString = ParseToFirstWhitespace(First)
          ! TODO why (len(trim(Line)) == 0)? if we use (len_trim(Line) == 0) above
          if (First(1:1) == "=" .or. len(trim(Line)) == 0) then
            cycle
          else
            select case (ToLower(trim(DumString)))

              case default
                write(STDOUT, "(3a)") " NOTE: Specification '", trim(Line), "' ignored"
                write(STDOUT, "(a)") " "

              case ("pedigreefile")
                if (.not. allocated(Second)) then
                  write(STDERR, "(a)") " ERROR: Must specify a file for PedigreeFile, i.e., PedigreeFile, Pedigree.txt"
                  write(STDERR, "(a)") ""
                  stop 1
                else
                  if (ToLower(trim(Second(1))) == "none") then
                    write(STDOUT, "(a)") " Not using pedigree"
                  else
                    Spec%PedigreePresent = .true.
                    write(Spec%PedigreeFile, *) trim(Second(1))
                    write(STDOUT, "(2a)") " Using pedigree file: ", trim(Spec%PedigreeFile)
                  end if
                end if

              ! case ("genotypefile")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a file for GenotypeFile, i.e., GenotypeFile, Genotype.txt"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     if (ToLower(trim(Second(1))) == "none") then
              !       write(STDOUT, "(a)") " Not using genotypes"
              !     else
              !       Spec%GenotypePresent = .true.
              !       write(Spec%GenotypeFile, *) trim(Second(1))
              !       write(STDOUT, "(2a)") " Using genotype file: ", trim(Spec%GenotypeFile)
              !     end if
              !   end if

              ! case ("haplotypefile")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a file for HaplotypeFile, i.e., HaplotypeFile, Haplotype.txt"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     if (ToLower(trim(Second(1))) == "none") then
              !       write(STDOUT, "(a)") " Not using haplotypes"
              !     else
              !       Spec%HaplotypePresent = .true.
              !       write(Spec%HaplotypeFile, *) trim(Second(1))
              !       write(STDOUT, "(2a)") " Using haplotype file: ", trim(Spec%HaplotypeFile)
              !     end if
              !   end if

              ! case ("locusweightfile")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a file for LocusWeightFile, i.e., LocusWeightFile, LocusWeight.txt"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     if (ToLower(trim(Second(1))) == "none") then
              !       write(STDOUT, "(a)") " Not using locus weights"
              !     else
              !       Spec%LocusWeightPresent = .true.
              !       write(Spec%LocusWeightFile, *) trim(Second(1))
              !       write(STDOUT, "(2a)") " Using locus weight file: ", trim(Spec%LocusWeightFile)
              !     end if
              !   end if

              ! case ("allelefreqfile")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a file for AlleleFreqFile, i.e., AlleleFreqFile, AlleleFreq.txt"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     if (ToLower(trim(Second(1))) == "none") then
              !       write(STDOUT, "(a)") " Not using precalculated/fixed allele frequencies"
              !     else
              !       Spec%AlleleFreqPresent = .true.
              !       if (ToLower(trim(Second(1))) == "fixed") then
              !         Spec%AlleleFreqFixed = .true.
              !         if (size(Second) > 1) then
              !           Spec%AlleleFreqAll = Char2Double(trim(Second(2)), "(f20.16)")
              !         else
              !           Spec%AlleleFreqAll = 0.5d0
              !         end if
              !         write(STDOUT, "(2a)") " Using fixed allele frequency: ", Real2Char(Spec%AlleleFreqAll, "(f6.4)")
              !       else
              !         write(Spec%AlleleFreqFile, *) trim(Second(1))
              !         write(STDOUT, "(2a)") " Using allele frequencies file: ", trim(Spec%AlleleFreqFile)
              !       end if
              !     end if
              !   end if

              ! case ("numberoftraits")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for NumberOfTraits, i.e., NumberOfTraits, 1"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%nTrait = Char2Int(trim(Second(1)))
              !     write(STDOUT, "(2a)") " Number of traits: ", trim(Spec%nTrait)
              !   end if

              ! case ("numberofloci")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for NumberOfLoci, i.e., NumberOfLoci, 10"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%nLocus = Char2Int(trim(Second(1)))
              !     write(STDOUT, "(2a)") " Number of loci: ", trim(Spec%nTrait)
              !   end if

              ! case ("gennrmtype")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a method for GenNrmType, i.e., GenNrmType, VanRaden"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     write(Spec%GenNrmType, *) ToLower(trim(Second(1)))
              !     if (trim(Spec%GenNrmType) /= "vanraden"        .and. &
              !         trim(Spec%GenNrmType) /= "vanraden1"       .and. &
              !         trim(Spec%GenNrmType) /= "vanraden2"       .and. &
              !         trim(Spec%GenNrmType) /= "yang"            .and. &
              !         trim(Spec%GenNrmType) /= "nejati-javaremi") then
              !         ! trim(Spec%GenNrmType) /= "day-williams") then
              !       write(STDERR, "(a)") " ERROR: GenNrmType must be either VanRaden=VanRaden1, VanRaden2, Yang, or Nejati-Javaremi"
              !       write(STDERR, "(a)") ""
              !       stop 1
              !     end if
              !     write(STDOUT, "(2a)") " Genotype NRM type: ", trim(Spec%GenNrmType)
              !   end if

              ! case ("fudgegennrmdiag")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for FudgeGenNrmDiag, i.e., FudgeGenNrmDiag, 0.001"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%FudgeGenNrmDiag = .true.
              !     Spec%FudgeGenNrmDiagFactor = Char2Double(trim(Second(1)), "(f20.16)")
              !     write(STDOUT, "(2a)") " Fudge genotype NRM diagonal: ", Real2Char(Spec%FudgeGenNrmDiagFactor, "(f6.4)")
              !   end if

              ! case ("blendgennrm")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for BlendGenNrm, i.e., BlendGenNrm, 0.95"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%PedNrm = .true.
              !     Spec%BlendGenNrm = .true.
              !     Spec%BlendGenNrmFactor = Char2Double(trim(Second(1)), "(f20.16)")
              !     write(STDOUT, "(2a)") " Blend genotype NRM: ", Real2Char(Spec%BlendGenNrmFactor, "(f6.4)")
              !   end if

              ! case ("fudgehapnrmdiag")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for FudgeHapNrmDiag, i.e., FudgeHapNrmDiag, 0.001"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%FudgeHapNrmDiag = .true.
              !     Spec%FudgeHapNrmDiagFactor = Char2Double(trim(Second(1)), "(f20.16)")
              !     write(STDOUT, "(2a)") " Fudge haplotype NRM diagonal: ", Real2Char(Spec%FudgeHapNrmDiagFactor, "(f6.4)")
              !   end if

              ! case ("blendhapnrm")
              !   if (.not. allocated(Second)) then
              !     write(STDERR, "(a)") " ERROR: Must specify a number for BlendHapNrm, i.e., BlendHapNrm, 0.95"
              !     write(STDERR, "(a)") ""
              !     stop 1
              !   else
              !     Spec%PedNrm = .true.
              !     Spec%BlendHapNrm = .true.
              !     Spec%BlendHapNrmFactor = Char2Double(trim(Second(1)), "(f20.16)")
              !     write(STDOUT, "(2a)") " Blend haplotype NRM: ", Real2Char(Spec%BlendHapNrmFactor, "(f6.4)")
              !   end if

              case ("outputformat")
                if (.not. allocated(Second)) then
                  write(STDERR, "(a)") " ERROR: Must specify two numbers for OutputFormat, i.e., OutputFormat, 16, 8"
                  write(STDERR, "(a)") ""
                  stop 1
                else
                  if (size(Second) < 2) then
                    write(STDERR, "(a)") " ERROR: Must specify two numbers for OutputFormat, i.e., OutputFormat, 16, 8"
                    write(STDERR, "(a)") ""
                    stop 1
                  else
                    Spec%OutputFormat = "f"//trim(Second(1))//"."//trim(Second(2))
                    write(STDOUT, "(2a)") " Output format: ", trim(Spec%OutputFormat)
                  end if
                end if

              case ("pedinbreeding")
                if (.not. allocated(Second)) then
                  write(STDERR, "(a)") " ERROR: Must specify Yes/No for PedInbreeding, i.e., PedInbreeding, Yes"
                  write(STDERR, "(a)") ""
                  stop 1
                else
                  if (ToLower(trim(Second(1))) == "yes") then
                    Spec%PedInbreeding = .true.
                    write(STDOUT, "(a)") " Calculate pedigree inbreeding: Yes"
                  else
                    write(STDOUT, "(a)") " Calculate pedigree inbreeding: No"
                  end if
                end if

              case ("pednrm")
                if (.not. allocated(Second)) then
                  write(STDERR, "(a)") " ERROR: Must specify Yes/No[,Format] for PedNrm, i.e., PedNrm, Yes , Matrix, Ija"
                  write(STDERR, "(a)") ""
                  stop 1
                else
                  if (ToLower(trim(Second(1))) == "yes") then
                    Spec%PedNrm = .true.
                    write(STDOUT, "(a)") " Calculate pedigree NRM: Yes"
                    nTmp = size(Second)
                    if (nTmp > 1) then
                      do i = 2, nTmp
                        if (ToLower(trim(Second(i))) == "matrix") then
                          Spec%PedNrmMat = .true.
                          write(STDOUT, "(a)") " Write pedigree NRM format: matrix"
                        end if
                        if (ToLower(trim(Second(i))) == "ija") then
                          Spec%PedNrmIja = .true.
                          write(STDOUT, "(a)") " Write pedigree NRM format: ija"
                        end if
                      end do
                    else
                      Spec%PedNrmMat = .true.
                      write(STDOUT, "(a)") " Write pedigree NRM format: matrix"
                    end if
                  else
                    write(STDOUT, "(a)") " Calculate pedigree NRM: No"
                  end if
                end if

              case ("pednrminv")
                if (.not. allocated(Second)) then
                  write(STDERR, "(a)") " ERROR: Must specify Yes/No[,Format] for PedNrmInv, i.e., PedNrmInv, Yes , Matrix, Ija"
                  write(STDERR, "(a)") ""
                  stop 1
                else
                  if (ToLower(trim(Second(1))) == "yes") then
                    Spec%PedNrmInv = .true.
                    write(STDOUT, "(a)") " Calculate pedigree NRM inverse: Yes"
                    nTmp = size(Second)
                    if (nTmp > 1) then
                      do i = 2, nTmp
                        if (ToLower(trim(Second(i))) == "matrix") then
                          Spec%PedNrmInvMat = .true.
                          write(STDOUT, "(a)") " Write pedigree NRM inverse format: matrix"
                        end if
                        if (ToLower(trim(Second(i))) == "ija") then
                          Spec%PedNrmInvIja = .true.
                          write(STDOUT, "(a)") " Write pedigree NRM inverse format: ija"
                        end if
                      end do
                    else
                      Spec%PedNrmInvMat = .true.
                      write(STDOUT, "(a)") " Write pedigree NRM inverse format: matrix"
                    end if
                  else
                    write(STDOUT, "(a)") " Calculate pedigree NRM inverse: No"
                  end if
                end if

        ! read(SpecUnit,*) DumC, Option
        ! Spec%GFullMat = trim(Option) == "Yes"

        ! read(SpecUnit,*) DumC, Option
        ! Spec%GIJA = trim(Option) == "Yes"

        ! if (Spec%GFullMat .or. Spec%GIJA) then
        !   Spec%MakeG = .true.
        ! end if

        ! read(SpecUnit,*) DumC, Option
        ! Spec%InvGFullMat = trim(Option) == "Yes"

        ! read(SpecUnit,*) DumC, Option
        ! Spec%InvGIJA = trim(Option) == "Yes"

        ! if (Spec%InvGFullMat .or. Spec%InvGIJA) then
        !   Spec%MakeInvG = .true.
        ! end if

        ! read(SpecUnit,*) DumC, Option
        ! Spec%HFullMat = trim(Option) == "Yes"

        ! read(SpecUnit,*) DumC, Option
        ! Spec%HIJA = trim(Option) == "Yes"

        ! if (Spec%HFullMat .or. Spec%HIJA) then
        !   Spec%MakeH = .true.
        !   Spec%MakeG = .true.
        !   Spec%MakeA = .true.
        ! end if

        ! read(SpecUnit,*) DumC, Option
        ! Spec%InvHFullMat = trim(Option) == "Yes"

        ! read(SpecUnit,*) DumC, Option
        ! Spec%InvHIJA = trim(Option) == "Yes"

        ! if (Spec%InvHFullMat .or. Spec%InvHIJA) then
        !   Spec%MakeInvH = .true.
        !   Spec%MakeG    = .true.
        !   Spec%MakeA    = .true.
        !   Spec%MakeInvA = .true.
        ! end if

        ! n = CountLines(Spec%SpecFile)
        ! if (n > 25) then
        !   write(STDOUT, "(a)") " BEWARE: Using an old A matrix is an experimental feature"
        !   write(STDOUT, "(a)") " BEWARE: - It requires id of individuals to be numeric and sequential and no unknown parents"
        !   write(STDOUT, "(a)") " BEWARE: - It requires the old A matrix between the parents of individuals whose A matrix will be built"
        !   write(STDOUT, "(a)") " BEWARE: - It switches off creation of other matrices (exit after AMat is done)"
        !   write(STDOUT, "(a)") " "
        !   read(SpecUnit, *) DumC, Spec%OldAMatFile, Spec%OldAMatNInd
        !   Spec%OldPedNrmFile = .true.
        ! end if

            end select
          end if

        end do ReadSpec
        close(SpecUnit)

        if ((Spec%PedInbreeding .or. Spec%PedNrm .or. Spec%PedNrmInv) .and. .not. Spec%PedigreePresent) then
          write(STDERR, "(a)") " ERROR: Must provide pedigree file to calculate pedigree inbreeding, NRM, or NRM inverse"
          write(STDERR, "(a)") ""
          stop 1
        end if

        if ((Spec%GenInbreeding .or. Spec%GenNrm .or. Spec%GenNrmInv) .and. .not. Spec%GenotypePresent) then
          write(STDERR, "(a)") " ERROR: Must provide genotype file to calculate genotype inbreeding, NRM, or NRM inverse"
          write(STDERR, "(a)") ""
          stop 1
        end if

        if ((Spec%HapInbreeding .or. Spec%HapNrm .or. Spec%HapNrmInv) .and. .not. Spec%HaplotypePresent) then
          write(STDERR, "(a)") " ERROR: Must provide haplotype file to calculate haplotype inbreeding, NRM, or NRM inverse"
          write(STDERR, "(a)") ""
          stop 1
        end if

        if (Spec%BlendGenNrm .and. .not. Spec%PedigreePresent) then
          write(STDERR, "(a)") " ERROR: Must provide pedigree file to blend genotype NRM with pedigree NRM"
          write(STDERR, "(a)") ""
          stop 1
        end if

        if (Spec%BlendHapNrm .and. .not. Spec%PedigreePresent) then
          write(STDERR, "(a)") " ERROR: Must provide pedigree file to blend haplotype NRM with pedigree NRM"
          write(STDERR, "(a)") ""
          stop 1
        end if

        ! Spec%nGenMat=0
        ! do i = 1, Spec%nTrait
        !   do j = i, Spec%nTrait
        !     Spec%nGenMat = Spec%nGenMat + 1
        !   end do
        ! end do

        ! if ((Spec%MakeG .or. Spec%MakeInvG .or. Spec%MakeH .or. Spec%MakeInvH) .and. .not. Spec%GenotypePresent) then
        !   write(STDOUT, "(a)") " NOTE: To create G or H matrix, a genotype file must be given --> ommited G or H."
        !   write(STDOUT, "(a)") " "
        !   Spec%MakeG    = .false.
        !   Spec%MakeInvG = .false.
        !   Spec%MakeH    = .false.
        !   Spec%MakeInvH = .false.
        ! end if

        ! if ((Spec%MakeA .or. Spec%MakeInvA .or. Spec%MakeH .or. Spec%MakeInvH) .and. .not. Spec%PedigreePresent) then
        !   write(STDOUT, "(a)") " NOTE: To create A or H matrix, a pedigree file must be given --> ommited A or H."
        !   write(STDOUT, "(a)") " "
        !   Spec%MakeA    = .false.
        !   Spec%MakeInvA = .false.
        !   Spec%MakeH    = .false.
        !   Spec%MakeInvH = .false.
        ! end if

      end if

    end function

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   AlphaRelateData constructor
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    function InitAlphaRelateData(Spec) result(Data)
      implicit none

      ! Arguments
      type(AlphaRelateSpec) :: Spec !< Specifications
      type(AlphaRelateData) :: Data !< @return Data

      ! Other
      type(PedigreeHolder) :: PedObj
      integer(int32) :: i, j, Stat, nCols, GenoInPed, nMissing
      integer(int32) :: OldGenNrmUnit, GenotypeUnit, AlleleFreqUnit, LocusWeightUnit

      character(len=SPECOPTIONLENGTH) :: DumC

      if (Spec%PedigreePresent) then
        ! Read in the pedigree
        PedObj = PedigreeHolder(Spec%PedigreeFile)
        Data%nIndPed = PedObj%PedigreeSize

        ! Sort and recode pedigree
        Data%RecPed = PedObj%MakeRecodedPedigreeArray()

        ! Free some memory
        call PedObj%DestroyPedigree
      end if

      ! if (Spec%GenotypePresent) then
      !   Data%nLocus = Spec%nLocus
      !   Data%nTrait = Spec%nTrait
      !   Data%nAnisG = CountLines(trim(Spec%GenotypeFile))
      !   write(STDOUT, "(a2,i6,a33)") "  ", Data%nAnisG," individuals in the genotype file"
      !   allocate(Data%Genos(Data%nAnisG,Data%nLocus))
      !   allocate(Data%ZMat(Data%nAnisG,Data%nLocus))
      !   allocate(Data%IdGeno(Data%nAnisG))
      !   !allocate(RecodeIdGeno(Data%nAnisG))
      !   open(newunit=GenotypeUnit, file=trim(Spec%GenotypeFile), status="old")
      !   do i = 1, Data%nAnisG
      !     read(GenotypeUnit,*) Data%IdGeno(i),Data%Genos(i,:)
      !   end do
      !   close(GenotypeUnit)
      !
      !   ! Allele frequencies
      !   allocate(Data%AlleleFreq(Data%nLocus))
      !   if (.not. Spec%AlleleFreqPresent) then
      !     !Calculate Allele Freq
      !     Data%AlleleFreq(:)=0.0d0
      !     do j = 1, Data%nLocus
      !       nMissing=0
      !       do i = 1, Data%nAnisG
      !         if ((Data%Genos(i,j) < 0.0) .or. (Data%Genos(i,j) > 2.0)) then
      !           nMissing = nMissing + 1
      !         else
      !           Data%AlleleFreq(j) = Data%AlleleFreq(j) + Data%Genos(i,j)
      !         end if
      !       end do
      !       ! Write the frequency of SNP j in array. If all SNPs are missing, then freq_j=0
      !       if (nAnisG > nMissing) then
      !         Data%AlleleFreq(j) = Data%AlleleFreq(j) / (2.0d0 * dble((Data%nAnisG - nMissing)))
      !       else
      !         Data%AlleleFreq(j) = 0.0d0
      !       end if
      !     end do
      !     open(newunit=AlleleFreqUnit, file="AlleleFreq.txt",status="unknown")
      !     do j = 1, Data%nLocus
      !       write(AlleleFreqUnit,*) j, Data%AlleleFreq(j)
      !     end do
      !     close(AlleleFreqUnit)
      !   else
      !     if (trim(Spec%AlleleFreqFile) == "Fixed") then
      !       Data%AlleleFreq(:) = Spec%AlleleFreqAll
      !       open(newunit=AlleleFreqUnit, file="AlleleFreq.txt",status="unknown")
      !       do j = 1, nLocus
      !         write(AlleleFreqUnit,*) j, Data%AlleleFreq(j)
      !       end do
      !       close(AlleleFreqUnit)
      !     else
      !       ! Read allele frequencies from file.
      !       open(newunit=AlleleFreqUnit, file=trim(Spec%AlleleFreqFile), status="old")
      !       do i = 1, Data%nLocus
      !         ! AlleleFrequencies are kept in second column to keep consistency with AlphaSim.
      !         read(AlleleFreqUnit, *, iostat=Stat) DumC, Data%AlleleFreq(i)
      !         if (Stat /= 0) then
      !           write(STDERR, "(a)") " ERROR: Problems reading allele frequency file."
      !           write(STDERR, "(a)") " "
      !           stop 1
      !         end if
      !       end do
      !       close(AlleleFreqUnit)
      !     end if
      !   end if
      !
      !   ! LocusWeight
      !   allocate(Data%LocusWeight(Data%nLocus,Data%nTrait))
      !   if (Spec%LocusWeightPresent) then
      !     open(newunit=LocusWeightUnit, file=trim(Spec%LocusWeightFile), status="old")
      !     do i = 1, Data%nLocus
      !       read(LocusWeightUnit,*) DumC, Data%LocusWeight(i,:)
      !     end do
      !     close(LocusWeightUnit)
      !   else
      !     Data%LocusWeight(:,:) = 1.0d0
      !   end if
      ! end if

      ! if (.not. Spec%PedigreePresent .and. Spec%GenotypePresent) then
      !   allocate(Data%RecPed(0:Data%nAnisG,4))
      !   Data%nAnisP = Data%nAnisG
      !   Data%RecPed(:,:) = 0
      !   Data%RecPed(:,4) = 1
      !   do i = 1, Data%nAnisP
      !     Data%RecPed(i,1) = i
      !   end do
      ! end if

      ! if (Spec%PedigreePresent .and. Spec%GenotypePresent) then
      !   ! These three vectors use the Pedigree animals as base,
      !   ! i.e. after reordering, the index for the nth pedigree animal is n.
      !   allocate(Data%MapAnimal(1:(Data%nAnisP + Data%nAnisG)))
      !   allocate(Data%MapToG(1:(Data%nAnisP + Data%nAnisG)))
      !   allocate(Data%AnimalsInBoth(1:Data%nAnisP + Data%nAnisG)) !TODO, should this be 1:(Data%nAnisP + Data%nAnisG)?
      !   Data%MapAnimal = 0
      !   Data%MapToG = .false.
      !   Data%AnimalsInBoth = .false.
      !   Data%nAnisH = Data%nAnisP
      !   do i = 1, Data%nAnisP
      !     Data%MapAnimal(i) = i
      !   end do
      !
      !   Data%AnimalsInBoth = .false.
      !   ! Match genotyped individuals to pedigree
      !   do i = 1, Data%nAnisG
      !     GenoInPed = 0
      !     do j = 1, Data%nAnisP
      !       if (trim(Data%IdGeno(i)) == trim(Id(j))) then ! TODO: can I include Id() into the Data object?
      !         Data%MapToG(j) = .true.
      !         Data%MapAnimal(j) = i
      !         Data%AnimalsInBoth(j) = .true.
      !         GenoInPed = 1
      !         exit
      !       end if
      !     end do
      !     if (GenoInPed == 0) then
      !       Data%nAnisH = Data%nAnisH + 1
      !       Data%MapAnimal(Data%nAnisH) = i
      !       Data%MapToG(Data%nAnisH) = .true.
      !       write(STDOUT, "(2a)") " Genotyped individual not in the pedigree file: ", trim(Data%IdGeno(i))
      !       write(STDOUT, "(a)")  " "
      !       ! stop 1
      !     end if
      !   end do
      ! end if
    end function

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   AlphaRelateData destructor
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    subroutine DestroyAlphaRelateData(This)
      implicit none
      class(AlphaRelateData) :: This !< Data

      if (allocated(This%RecPed%OriginalId)) then
        deallocate(This%RecPed%OriginalId)
        deallocate(This%RecPed%Generation)
        deallocate(This%RecPed%Id)
      end if

      if (allocated(This%PedInbreeding)) then
        deallocate(This%PedInbreeding)
      end if

      if (allocated(This%PedNrm)) then
        deallocate(This%PedNrm)
      end if

      if (allocated(This%PedNrmInv)) then
        deallocate(This%PedNrmInv)
      end if
    end subroutine

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   Calculate pedigree inbreeding on AlphaRelateData
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    subroutine CalcPedInbreeding(This)
      implicit none
      class(AlphaRelateData) :: This !< @return Data that will hold pedigree inbreeding

      if (.not. allocated(This%RecPed%Id)) then
        write(STDERR, "(a)") " ERROR: Pedigree (RecPed) must be available to calculate pedigree inbreeding"
        write(STDERR, "(a)") " "
        stop 1
      else
        allocate(This%PedInbreeding(0:This%nIndPed))
        This%PedInbreeding = PedInbreeding(RecPed=This%RecPed%Id, n=This%nIndPed)
      end if
    end subroutine

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   Calculate pedigree inbreeding using the Meuwissen and
    !!          Luo (1992, GSE 24: 305-313) method
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk & John Hickey, john.hickey@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    function PedInbreeding(RecPed, n) result(f)
      implicit none

      ! Arguments
      integer(int32) :: RecPed(1:3,0:n) !< Sorted and recoded pedigree array
      integer(int32) :: n               !< Number of individuals in pedigree
      real(real64) :: f(0:n)            !< @return Pedigree inbreeding

      ! Other
      integer(int32) :: i, is, id, j, k, ks, kd
      integer(int32) :: ped(3,0:n), point(0:n)
      real(real64) :: l(n), d(n), fi, r

      point(:) = 0
      l(:) = 0.0d0
      d(:) = 0.0d0

      f(:) = 0.0d0
      ped(1,:) = RecPed(1,:)
      ped(2,:) = RecPed(2,:)
      ped(3,:) = RecPed(3,:)

      f(0) = -1.0d0
      do i = 1, n
        is = RecPed(2,i)
        id = RecPed(3,i)
        ped(2,i) = max(is,id)
        ped(3,i) = min(is,id)
        d(i) = 0.5d0 - 0.25d0 * (f(is) + f(id))
        if (is .eq. 0 .or. id .eq. 0) then
          f(i) = 0.0d0
        else if ((ped(2,i-1) .eq. ped(2,i)) .and. (ped(3,i-1) .eq. ped(3,i))) then
          f(i) = f(i-1)
        else
          fi = -1.0d0
          l(i) = 1.0d0
          j = i

          do while (j .ne. 0)
            k = j
            r = 0.5d0 * l(k)
            ks = ped(2,k)
            kd = ped(3,k)
            if (ks .gt. 0) then
              do while (point(k) .gt. ks)
                k = point(k)
              end do
              l(ks) = l(ks) + r
              if (ks .ne. point(k)) then
                point(ks) = point(k)
                point(k) = ks
              end if
              if (kd .gt. 0) then
                do while (point(k) .gt. kd)
                  k = point(k)
                end do
                l(kd) = l(kd) + r
                if (kd .ne. point(k)) then
                  point(kd) = point(k)
                  point(k) = kd
                end if
              end if
            end if
            fi = fi + l(j) * l(j) * d(j)
            l(j) = 0.0d0
            k = j
            j = point(j)
            point(k) = 0
          end do

          f(i) = fi
        end if
      end do
    end function

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   Write pedigree inbreeding to a file
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    subroutine WritePedInbreeding(This, Spec, File)
      implicit none
      class(AlphaRelateData) :: This !< Data
      type(AlphaRelateSpec) :: Spec  !< Specifications
      character(len=*) :: File       !< @return File that will hold Original Id and pedigree inbreeding

      integer(int32) :: PedInbreedingUnit, i

      if (.not. allocated(This%PedInbreeding)) then
        write(STDERR, "(a)") " ERROR: Pedigree inbreeding not calculated"
        write(STDERR, "(a)") " "
        stop 1
      else
        open(newunit=PedInbreedingUnit, file=trim(File), status="unknown")
        do i = 1, This%nIndPed
          write(PedInbreedingUnit, "(a"//Int2Char(IDLENGTH)//","//Spec%OutputFormat//")") This%RecPed%OriginalId(i), This%PedInbreeding(i)
        end do
        close(PedInbreedingUnit)
      end if
    end subroutine

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   Calculate pedigree NRM on AlphaRelateData
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    subroutine CalcPedNrm(This, Spec)
      implicit none
      class(AlphaRelateData) :: This !< @return Data that will hold pedigree NRM
      type(AlphaRelateSpec) :: Spec  !< Specifications

      if (.not. allocated(This%RecPed%Id)) then
        write(STDERR, "(a)") " ERROR: Pedigree (RecPed) must be available to calculate pedigree NRM"
        write(STDERR, "(a)") " "
        stop 1
      else
        if (.not. Spec%OldPedNrmPresent) then
          allocate(This%PedNrm(0:This%nIndPed,0:This%nIndPed))
          This%PedNrm = PedNrm(RecPed=This%RecPed%Id, n=This%nIndPed)
        else
          ! TODO
        end if
      end if
    end subroutine

    !###########################################################################

    !---------------------------------------------------------------------------
    !> @brief   Calculate pedigree NRM
    !> @author  Gregor Gorjanc, gregor.gorjanc@roslin.ed.ac.uk & John Hickey, john.hickey@roslin.ed.ac.uk
    !> @date    December 22, 2016
    !---------------------------------------------------------------------------
    function PedNrm(RecPed, n) result(Nrm)
      implicit none

      ! Arguments
      integer(int32) :: RecPed(1:3,0:n) !< Sorted and recoded pedigree array
      integer(int32) :: n               !< Number of individuals in pedigree
      real(real64) :: Nrm(0:n,0:n)      !< @return Pedigree NRM

      ! Other
      integer(int32) :: Ind1, Ind2, Par1, Par2

      Nrm(0:n,0:n) = 0.0d0
      do Ind1 = 1, n
          Par1 = max(RecPed(2,Ind1), RecPed(3,Ind1))
          Par2 = min(RecPed(2,Ind1), RecPed(3,Ind1))
          do Ind2 = 1, Ind1 - 1
              Nrm(Ind2,Ind1) = (Nrm(Ind2,Par1) + Nrm(Ind2,Par2)) / 2.0d0
              Nrm(Ind1,Ind2) = Nrm(Ind2,Ind1)
          end do

          Nrm(Ind1,Ind2) = 1.0d0 + Nrm(Par1,Par2) / 2.0d0
      end do
    end function

    !   integer(int32) :: i,j,k,l,m,n,s,d,div,MinId,MaxId,Start,Endin

    !   real(real64) :: AMatAvg

    !   logical :: AnimToWrite(nAnisP)

    !   if (OldAMatPresent) then
    !     open(newunit=OldAMatUnit, file=OldAMatFile, status="unknown")
    !     allocate(OldAMatId(OldAMatNInd))
    !     do j = 1, OldAMatNInd
    !       read(OldAMatUnit, *) OldAMatId(j)
    !     end do
    !     rewind(OldAMatUnit)
    !     MinId = minval(OldAMatId)
    !     MaxId = maxval(OldAMatId)
    !     allocate(AMat(1:(OldAMatNInd+nAnisP-MaxId),&
    !                   1:(OldAMatNInd+nAnisP-MaxId)))
    !     AMat = 0.0d0
    !     do j = 1, OldAMatNInd
    !       read(OldAMatUnit, *) OldAMatId(j), AMat(1:OldAMatNInd,j)
    !       if (j > 1) then
    !         if (.not.(OldAMatId(j) > OldAMatId(j-1))) then
    !           print *, "Id are not sequential!"
    !           stop 1
    !         end if
    !       end if
    !     end do
    !     k = OldAMatNInd
    !     do i=MaxId+1,nAnisP
    !         k = k + 1
    !         s = RecPed(i,2) - MinId + 1
    !         d = RecPed(i,3) - MinId + 1
    !         l = k
    !         do j=1,k-1
    !             AMat(j,k)=(AMat(j,s)+AMat(j,d))/2.0d0
    !             AMat(k,j)=AMat(j,k)
    !             !print *,i,k,j,s,d,AMat(j,s),AMat(j,d),AMat(j,k)
    !         end do
    !         AMat(k,k)=1.0d0+AMat(s,d)/2.0d0
    !         !print *,i,k,s,d,AMat(s,d),AMat(k,k)
    !     end do
    !     RecPed(1:nAnisP,4) = 0
    !     RecPed((MaxId+1):nAnisP,4) = 1
    !   else

    !   if (AFullMat) then
    !     AnimToWrite = RecPed(1:nAnisP,4) == 1
    !     s = count(AnimToWrite)
    !     write(*,"(a32,i6,a11)") " Start writing A full matrix for", s," individuals"
    !     write(nChar,*) s
    !     fmt="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !     open(unit=202,file="AFullMatrix.txt",status="unknown")
    !     if (.not.OldAMatPresent) then
    !       do m=1,nAnisP
    !         if (AnimToWrite(m)) then
    !           write(202,fmt) Id(m), pack(AMat(1:nAnisP,m), AnimToWrite)
    !         end if
    !       end do
    !     else
    !       Start = OldAMatNInd+1
    !       Endin = size(AMat,1)
    !       do m=Start,Endin
    !         !write(*,fmt)   Id(m+MinId-1), AMat(Start:Endin,m)
    !         write(202,fmt) Id(m+MinId-1), AMat(Start:Endin,m)
    !       end do
    !     end if
    !     close(202)
    !     print*, "End writing A full matrix"
    !   end if

    !   if (OldAMatPresent) then
    !     stop
    !   end if

    !   if (AIJA) then
    !     ! TODO: AnimToWrite is not being used here
    !     write(*,"(a24,i6,a11)") " Start writing A ija for", s," individuals"
    !     fmt="(2a20,"//trim(adjustl(OutputFormat))//")"
    !     open(unit=202,file="Aija.txt",status="unknown")
    !     do m=1,nAnisP
    !       do n=m,nAnisP
    !         if (AMat(n,m) > 0.0d0)  then
    !           write(202,fmt) Id(n),Id(m),AMat(n,m)
    !         end if
    !       end do
    !     end do
    !     close(202)
    !     print*, "End writing A ija"
    !   end if

    !   ! Record diagonals of animals in both A and G:
    !   if ((MakeH .or. MakeInvH) .and. ScaleGByRegression) then
    !     n = Count(AnimalsInBoth)
    !     allocate(Adiag(0:n))
    !     div = dble(n**2)
    !     AMatAvg = 0.0d0
    !     k = 0
    !     do i = 1,nAnisP
    !       if (.not. AnimalsInBoth(i)) then
    !         cycle
    !       end if
    !       k = k + 1
    !       Adiag(k) = AMat(i,i)
    !       do j=1,nAnisP
    !         if (AnimalsInBoth(j)) then
    !           AMatAvg=AMatAvg + AMat(j,i) * 2.0d0 / div
    !         end if
    !       end do
    !     end do
    !     Adiag(0) = AMatAvg
    !   end if
    ! end subroutine

    !   integer(int32) :: i,m,n,s,FId,MId

    !   real(real64) :: Inbreeding(0:nAnisP),Dii(nAnisP),InvDii

    !   character(len=1000) :: nChar,fmt

    !   logical :: AnimToWrite(nAnisP),FIdKnown,MIdKnown

    !   allocate(InvAMat(0:nAnisP,0:nAnisP))

    !   print*, "Start calculating inbreeding coefficients"
    !   call dinbreeding(RecPed(0:nAnisP,1),RecPed(0:nAnisP,2),RecPed(0:nAnisP,3),Inbreeding,nAnisP)
    !   open(unit=202,file="PedigreeBasedInbreeding.txt",status="unknown")
    !   print*, "End calculating inbreeding coefficients"
    !   do i=1,nAnisP
    !     write(202,"(a20,20000f10.5)") Id(i),Inbreeding(i)
    !   end do
    !   close(202)

    !   print*, "Start making A inverse"
    !   InvAMat=0.0d0
    !   ! TODO: could remove the if statements bellow since InvAMat has zeroth row and column
    !   !       and could simply increment values in those positions - they are omitted on
    !   !       printout anyhow
    !   do i=1,nAnisP
    !     FId=RecPed(i,2)
    !     FIdKnown=FId/=0
    !     MId=RecPed(i,3)
    !     MIdKnown=MId/=0
    !     ! Variance of founder effects and Mendelian sampling terms
    !     Dii(i)=1.0d0
    !     if (FIdKnown) then
    !       Dii(i)=Dii(i)-0.25d0*(1.0d0+Inbreeding(FId))
    !     end if
    !     if (MIdKnown) then
    !       Dii(i)=Dii(i)-0.25d0*(1.0d0+Inbreeding(MId))
    !     end if
    !     ! Precision for the individual
    !     InvDii=1.0d0/Dii(i)
    !     InvAMat(i,i)=InvDii
    !     ! Add precision to the father and set the co-precision
    !     if (FIdKnown) then
    !       InvAMat(FId,FId)=InvAMat(FId,FId)+InvDii/4.0d0
    !       InvAMat(i,FId)=InvAMat(i,FId)-InvDii/2.0d0
    !       InvAMat(FId,i)=InvAMat(i,FId)
    !     end if
    !     ! Add precision to the mother and set the co-precision
    !     if (MIdKnown) then
    !       InvAMat(MId,MId)=InvAMat(MId,MId)+InvDii/4.0d0
    !       InvAMat(i,MId)=InvAMat(i,MId)-InvDii/2.0d0
    !       InvAMat(MId,i)=InvAMat(i,MId)
    !     end if
    !     ! Add co-precision between the father and mother
    !     if (FIdKnown .and. MIdKnown) then
    !       InvAMat(FId,MId)=InvAMat(FId,MId)+InvDii/4.0d0
    !       InvAMat(MId,FId)=InvAMat(FId,MId)
    !     end if
    !   end do
    !   print*, "Finished making A inverse"

    !   if (InvAFullMat) then
    !     AnimToWrite = RecPed(1:nAnisP,4) == 1
    !     s = count(AnimToWrite)
    !     write(*,"(a40,i6,a11)") " Start writing A inverse full matrix for", s," individuals"
    !     write(nChar,*) s
    !     fmt="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !     open(unit=202,file="InvAFullMatrix.txt",status="unknown")
    !     do m=1,nAnisP
    !       if (AnimToWrite(m)) then
    !         write(202,fmt) Id(m), pack(InvAMat(1:nAnisP,m), AnimToWrite)
    !       end if
    !     end do
    !     close(202)
    !     print*, "End writing A inverse full matrix"
    !   end if

    !   if (InvAIJA) then
    !     print*, "Start writing A inverse ija"
    !     fmt="(2a20,"//trim(adjustl(OutputFormat))//")"
    !     open(unit=202,file="InvAija.txt",status="unknown")
    !     do m=1,nAnisP
    !       do n=m,nAnisP
    !         if (InvAMat(n,m) /= 0.0d0) then
    !           write(202,fmt) Id(n),Id(m),InvAMat(n,m)
    !         end if
    !       end do
    !     end do
    !     close(202)
    !     print*, "End writing A inverse ija"
    !   end if
    ! end subroutine

    !###########################################################################

    ! subroutine MakeGAndInvGMatrix
    !   implicit none

    !   integer(int32) :: i,j,k,l,m,n,WhichMat

    !   real(real64) :: nLocusD, DMatSum, Tmp, Tmp2, Tmp3
    !   real(real64), allocatable :: TmpZMat(:,:), DMat(:,:)

    !   character(len=1000) :: filout,nChar,fmt

    !   allocate(GMat(nAnisG,nAnisG,nGMat))
    !   allocate(tZMat(nLocus,nAnisG))
    !   allocate(TmpZMat(nAnisG,nLocus))
    !   if (LocusWeightPresent) then
    !     allocate(DMat(nLocus,nLocus))
    !     DMat(:,:)=0.0d0
    !   end if

    !   print*, "Start making G - ", trim(GType)

    !   nLocusD = dble(nLocus)

    !   ! Center allele dosages (Z)
    !   if (trim(GType) == "VanRaden"  .or.&
    !       trim(GType) == "VanRaden1" .or.&
    !       trim(GType) == "VanRaden2" .or.&
    !       trim(GType) == "Yang") then
    !     do j=1,nLocus
    !       do i=1,nAnisG
    !         if ((Genos(i,j)>=0.0).and.(Genos(i,j)<=2.0)) then
    !           ZMat(i,j)=Genos(i,j)-2.0d0*AlleleFreq(j)
    !         else
    !           ZMat(i,j)=0.0d0
    !         end if
    !       end do
    !     end do
    !   end if
    !   if (trim(GType) == "Nejati-Javaremi" .or.&
    !       trim(GType) == "Day-Williams") then
    !     do j=1,nLocus
    !       do i=1,nAnisG
    !         if ((Genos(i,j)>=0.0).and.(Genos(i,j)<=2.0)) then
    !           ZMat(i,j)=Genos(i,j)-1.0d0
    !         else
    !           ZMat(i,j)=0.d00 ! TODO: is this OK?
    !         end if
    !       end do
    !     end do
    !   end if
    !   ! Scale centered allele dosages
    !   if (trim(GType) == "VanRaden2" .or. trim(GType) == "Yang") then
    !     do j=1,nLocus
    !       Tmp=2.0d0*AlleleFreq(j)*(1.0d0-AlleleFreq(j))
    !       if (Tmp > tiny(Tmp)) then
    !         ZMat(:,j)=ZMat(:,j)/sqrt(Tmp)
    !       end if
    !     end do
    !   end if

    !   ! Z'
    !   tZMat=transpose(ZMat)

    !   WhichMat=0
    !   do j=1,nTrait
    !     do i=j,nTrait
    !       WhichMat=WhichMat+1

    !       ! ZHZ'
    !       if (LocusWeightPresent) then
    !         DMatSum=0.0d0
    !         do k=1,nLocus
    !           DMat(k,k)=sqrt(LocusWeight(k,i))*sqrt(LocusWeight(k,j))
    !           DMatSum=DMatSum+DMat(k,k)
    !         end do
    !         ! TODO: use DGEMM equivalent for X * Diagonal
    !         TmpZMat=matmul(ZMat,DMat)
    !         ! TODO: use DGEMM
    !         GMat(:,:,WhichMat)=matmul(TmpZMat,tZMat)
    !       else
    !         ! TODO: use DGEMM
    !         GMat(:,:,WhichMat)=matmul(ZMat,tZMat)
    !       end if

    !       ! ZHZ'/Denom
    !       if (trim(GType) == "VanRaden" .or. trim(GType) == "VanRaden1") then
    !         GMat(:,:,WhichMat)=GMat(:,:,WhichMat)/(2.0d0*sum(AlleleFreq(:)*(1.0d0-AlleleFreq(:))))
    !       end if
    !       if (trim(GType) == "VanRaden2" .or.&
    !           trim(GType) == "Yang"      .or.&
    !           trim(GType) == "Nejati-Javaremi") then
    !         GMat(:,:,WhichMat)=GMat(:,:,WhichMat)/nLocusD
    !       end if

    !       ! Put back scale from [-1,1] to [0,2]
    !       if (trim(GType) == "Nejati-Javaremi") then
    !         if (LocusWeightPresent) then
    !           Tmp=DMatSum/nLocusD
    !         else
    !           Tmp=1.0d0
    !         end if
    !         GMat(:,:,WhichMat)=GMat(:,:,WhichMat)+Tmp
    !       end if

    !       ! TODO: needs testing (was getting some weird values)
    !       ! if (trim(GType) == "Day-Williams") then
    !       !   Tmp=0.0d0
    !       !   do k=1,nLocus
    !       !     Tmp=Tmp + AlleleFreq(k)*AlleleFreq(k) + (1.0d0-AlleleFreq(k))*(1.0d0-AlleleFreq(k))
    !       !   end do
    !       !   do k=1,nAnisG
    !       !     do l=1,nAnisG
    !       !       ! TODO: could do just lower triangle, but would have to jump around in memory, i.e., G(j,i)=G(i,j)
    !       !       !       which is faster?
    !       !       ! GMat(l,k,WhichMat)+nLocus is the total number of (observed) IBS matches, i.e., 2*e(i,j) in Day-Williams
    !       !       ! Multiply and divide by 2, because we are building covariance matrix instead of probability matrix
    !       !       GMat(l,k,WhichMat)=2.0d0*((GMat(l,k,WhichMat)+nLocusD)/2.0d0-Tmp)/(nLocusD-Tmp)
    !       !     end do
    !       !   end do
    !       ! end if

    !       ! Different diagonal for Yang altogether
    !       if (trim(GType) == "Yang") then
    !         do l=1,nAnisG
    !           GMat(l,l,WhichMat)=0.0d0
    !         end do
    !         do k=1,nLocus
    !           Tmp=2.0d0*AlleleFreq(k)*(1.0d0-AlleleFreq(k))
    !           if (Tmp > tiny(Tmp)) then
    !             if (LocusWeightPresent) then
    !               Tmp2=sqrt(LocusWeight(k,i))*sqrt(LocusWeight(k,j))
    !             else
    !               Tmp2=1.0d0
    !             end if
    !             do l=1,nAnisG
    !               Tmp3=Tmp2 * (1.0d0 + ((Genos(l,k)*Genos(l,k) - (1.0d0+2.0d0*AlleleFreq(k))*Genos(l,k) + 2.0d0*AlleleFreq(k)*AlleleFreq(k)) / Tmp))/nLocusD
    !               GMat(l,l,WhichMat)=GMat(l,l,WhichMat)+Tmp3
    !             end do
    !           end if
    !         end do
    !       end if

    !       ! Fudge diagonal
    !       do l=1,nAnisG
    !         GMat(l,l,WhichMat)=GMat(l,l,WhichMat)+DiagFudge
    !       end do

    !       ! Export etc.
    !       if (GFullMat) then
    !         write(filout,'("GFullMatrix"i0,"-"i0".txt")')i,j
    !         write(nChar,*) nAnisG
    !         fmt="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !         open(unit=202,file=trim(filout),status="unknown")
    !         do m=1,nAnisG
    !           write(202,fmt) IdGeno(m),GMat(:,m,WhichMat)
    !         end do
    !         close(202)
    !       end if

    !       if (GIJA) then
    !         fmt="(2a20,"//trim(adjustl(OutputFormat))//")"
    !         write(filout,'("Gija"i0,"-"i0".txt")')i,j
    !         open(unit=202,file=trim(filout),status="unknown")
    !         do m=1,nAnisG
    !           do n=m,nAnisG
    !             ! No test for non-zero here as all elements are non-zero
    !             write(202,fmt) IdGeno(n),IdGeno(m),GMat(n,m,WhichMat)
    !           end do
    !         end do
    !         close(202)
    !       end if

    !       if (MakeInvG) then
    !         allocate(InvGMat(nAnisG,nAnisG,nGMat))

    !         print*, "Start inverting G - ", trim(GType)
    !         InvGMat(:,:,WhichMat)=GMat(:,:,WhichMat)
    !         call invert(InvGMat(:,:,WhichMat),nAnisG,.true., 1)

    !         print*, "Finished inverting G - ", trim(GType)

    !         if (InvGFullMat) then
    !           write(nChar,*) nAnisG
    !           fmt="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !           write(filout,'("InvGFullMatrix"i0,"-"i0".txt")')i,j
    !           open(unit=202,file=trim(filout),status="unknown")
    !           do m=1,nAnisG
    !             write(202,fmt) IdGeno(m),InvGMat(:,m,WhichMat)
    !           end do
    !           close(202)
    !         end if

    !         if (InvGIJA) then
    !           write(filout,'("InvGija"i0,"-"i0".txt")')i,j
    !           fmt="(2a20,"//trim(adjustl(OutputFormat))//")"
    !           open(unit=202,file=trim(filout),status="unknown")
    !           do m=1,nAnisG
    !             do n=m,nAnisG
    !               write(202,fmt) IdGeno(n),IdGeno(m),InvGMat(n,m,WhichMat)
    !             end do
    !           end do
    !           close(202)
    !         end if
    !       end if

    !     end do
    !   end do
    !   deallocate(tZMat)
    !   deallocate(TmpZMat)
    !   print*, "Finished making G - ", trim(GType)
    ! end subroutine

    !###########################################################################

    ! subroutine MakeHAndInvHMatrix
    !   ! Feature added by Stefan Hoj-Edwards, February 2016
    !   ! Making the Inverse H matrix ala Aguilar et al 201? and Christensen 2012

    !   ! Prerequisite and assumptions for this subroutine:
    !   ! There is given both a pedigree and genotype file, and there is an overlap
    !   ! of animals between two data sets.
    !   ! Diagonals of from both A have been collected during MakeA and MakeG,
    !   ! as well as average of A22.
    !   ! GMat is already calculated and loaded in memory.
    !   ! InvA is calculated an loaded into memory.
    !   !
    !   ! Further assumes that animals are ordered the same in both A and G.

    !   implicit none

    !   integer(int32) :: i,j,k,m,p,q,div,t1,t2,whichMat,nBoth
    !   integer(int32),allocatable :: MapToA11(:), MapToA22(:) !Gmap(:),

    !   real(real64) :: GMatavg, nom, denom, slope, intercept, Gmean, Amean, Hii
    !   real(real64),allocatable :: Gdiag(:), Hrow(:), A22(:,:), InvA22(:,:), G22(:,:), A11(:,:), A12(:,:), tmp(:,:), Gboth(:,:)

    !   character(len=1000) :: nChar,fmt1, fmt2,filout
    !   character(len=IDLENGTH),allocatable :: Ids(:)

    !   logical,allocatable :: AnimToWrite(:)

    !   nboth = count(AnimalsInBoth)
    !   ! Make H and/or InvH
    !   allocate(Ids(1:nAnisH))
    !   allocate(AnimToWrite(1:nAnisH))

    !   do i=1,nAnisH
    !     if (MapToG(i)) then
    !       Ids(i) = IdGeno(MapAnimal(i))
    !       AnimToWrite(i) = .true.
    !     else
    !       Ids(i) = Id(MapAnimal(i))
    !       AnimToWrite(i) = RecPed(MapAnimal(i),4)
    !     end if
    !   end do

    !   allocate(InvA22(nBoth,nBoth))
    !   allocate(MapToA22(nAnisH))
    !   if (MakeH) then
    !     allocate(A22(nBoth,nBoth))
    !   end if

    !   k = 0
    !   do i=1,nAnisP
    !     if (.not. AnimalsInBoth(i)) then
    !       cycle
    !     end if
    !     k = k + 1
    !     MapToA22(i) = k
    !     m = 0
    !     do j=1,nAnisP
    !       if (.not. AnimalsInBoth(j)) then
    !         cycle
    !       end if
    !       m = m + 1
    !       InvA22(m,k) = AMat(j,i)
    !     end do
    !   end do
    !   if (MakeH) then
    !     A22 = InvA22
    !   end if

    !   call invert(InvA22,size(InvA22,1),.true.,1)

    !   ! This is the G matrix in Legarra,
    !   ! Sadly, no genotypes where provided, instead the resulting G matrix was.
    !   if (.false.) then
    !     print *, "Overwriting G matrix with example in Legarra 2008!"
    !     do i=1,nAnisG
    !       do j=1,nAnisG
    !         if (i==j) then
    !           GMat(i,j,1) = 1
    !         else
    !           GMat(i,j,1) = 0.7
    !         end if
    !       end do
    !     end do
    !   end if

    !   whichMat = 0
    !   do t1=1,nTrait
    !     do t2=t1,nTrait
    !       whichMat = whichMat + 1

    !       write(*, '(" Starting on H matrix "i0" - "i0)') t1, t2

    !       ! Collect G22
    !       allocate(G22(nAnisG,nAnisG))

    !       G22 = 0.0d0
    !       do j=1,nAnisG
    !         do i=1,nAnisG
    !           nom = GMat(i,j,whichMat)
    !           if (i == j) then
    !             nom = nom - DiagFudge
    !           end if
    !           G22(i,j) = nom
    !         end do
    !       end do

    !       if (ScaleGByRegression) then
    !         allocate(Gdiag(0:nBoth))
    !         Gdiag=0.0d0
    !         GMatavg=0.0d0
    !         div=dble(nBoth**2)
    !         !allocate(Gmap(nBoth))

    !         k = 0
    !         do i=1,nAnisH
    !           if (.not. AnimalsInBoth(i)) then
    !             cycle
    !           end if
    !           k = k+1
    !           Gdiag(k) = G22(MapAnimal(i),MapAnimal(i))
    !           do j=1,nAnisH
    !             if (.not. AnimalsInBoth(j)) then
    !               cycle
    !             end if
    !             GMatavg=GMatavg + G22(MapAnimal(j),MapAnimal(i))/div
    !           end do
    !         end do
    !         Gdiag(0) = GMatavg

    !         ! Now do simple linear regression
    !         nom = 0.0d0
    !         denom = 0.0d0
    !         Gmean = sum(Gdiag) / dble(size(Gdiag, 1))
    !         Amean = sum(Adiag) / dble(size(Adiag, 1))
    !         do i=0,ubound(Adiag, 1)
    !           nom = nom + (Adiag(i) - Amean) * (Gdiag(i) - Gmean)
    !           denom = denom + (Adiag(i) - Amean)**2
    !         end do
    !         slope = nom / denom
    !         intercept = Amean - slope * Gmean

    !         ! Scale G
    !         G22 = slope * G22 + intercept
    !         !do i=1,nAnisG
    !         ! G22(i,i) = G22(i,i) + DiagFudge
    !         !end do
    !         print *, "Scaling of G:"
    !         write(*, "(a,f7.4,a,f7.4)"), " G* = G x ", slope, " + ", intercept
    !         deallocate(Gdiag)
    !       else
    !         do i=1,nAnisH
    !           if (.not. MapToG(i)) then
    !             cycle
    !           end if
    !           do j=1,nAnisH
    !             if (.not. MapToG(j)) then
    !               cycle
    !             end if
    !             if (AnimalsInBoth(i) .and. AnimalsInBoth(j)) then
    !               G22(MapAnimal(j),MapAnimal(i)) = ScaleGToA * G22(MapAnimal(j),MapAnimal(i)) + (1.0d0 - ScaleGToA) * AMat(j,i)
    !             end if
    !           end do
    !         end do
    !       end if

    !       do i=1,nAnisG
    !         G22(i,i) = G22(i,i) + DiagFudge
    !       end do

    !       allocate(Hrow(1:count(AnimToWrite)))

    !       if (MakeH) then

    !         allocate(A11(nAnisP-nBoth, nAnisP-nBoth))
    !         allocate(A12(nAnisP-nBoth, nBoth))
    !         allocate(MapToA11(nAnisP))
    !         allocate(tmp(nAnisP-nBoth, nBoth))
    !         allocate(Gboth(nBoth,nBoth))

    !         MapToA11 = 0
    !         k = 0
    !         p = 0
    !         do i=1,nAnisP
    !           if (AnimalsInBoth(i)) then
    !             p = p + 1
    !             q = 0
    !             do j=1,nAnisP
    !               if (.not. AnimalsInBoth(j)) then
    !                 cycle
    !               end if
    !               q = q + 1
    !               Gboth(q,p) = G22(MapAnimal(j),MapAnimal(i))
    !             end do
    !           else
    !             k = k+1
    !             m = 0
    !             MapToA11(i) = k
    !             do j=1,nAnisP
    !               if (AnimalsInBoth(j)) then
    !                 A12(k,MapAnimal(j)) = AMat(j,i)  !A12 is not symmetrical
    !               else
    !                 m = m+1
    !                 A11(m,k) = AMat(j,i)
    !               end if
    !             end do
    !           end if
    !         end do

    !         ! TODO: use DGEMM
    !         tmp = matmul(A12, InvA22)
    !         !tmp = matmul(matmul(tmp, (Gboth - A22)), transpose(tmp))
    !         tmp = matmul(tmp, (Gboth-A22))
    !         tmp = matmul(tmp, InvA22)
    !         !tmp = matmul(tmp, transpose(A12))

    !         A11 = A11 + matmul(tmp, transpose(A12))
    !         A12 = matmul(matmul(A12, InvA22), Gboth)

    !         deallocate(tmp)
    !         deallocate(Gboth)

    !         print *, "Start writing H matrices (full and/or ija)"

    !         if (HFullMat) then
    !           write(filout,'("HFullMatrix"i0,"-"i0".txt")') t1,t2
    !           write(nChar,*) nAnisH
    !           fmt1="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !           open(unit=202,file=trim(filout),status="unknown")
    !         end if

    !         if (HIJA) then
    !           write(filout,'("Hija"i0,"-"i0".txt")') t1,t2
    !           fmt2="(a20,a20,"//trim(adjustl(OutputFormat))//")"
    !           open(unit=204,file=trim(filout),status="unknown")
    !         end if

    !         do i=1,nAnisH
    !           if (AnimToWrite(i) .eq. .false.) then
    !             cycle
    !           end if
    !           Hrow = 0
    !           k = 0
    !           do j=1,nAnisH
    !             if (AnimToWrite(j) .eq. .false.) then
    !               cycle
    !             end if
    !             k = k + 1
    !             if (MapToG(i)) then
    !               if (MapToG(j)) then
    !                 Hii = G22(MapAnimal(i),MapAnimal(j))
    !               else
    !                 Hii = A12(MapToA11(j),MapAnimal(i)) ! Remember to transpose
    !               end if
    !             else
    !               if (MapToG(j)) then
    !                 Hii = A12(MapToA11(i),MapAnimal(j))
    !               else
    !                 Hii = A11(MapToA11(i),MapToA11(j))
    !               end if
    !             end if
    !             if (InvHIJA .and. i .le. j .and. Hii /= 0.0d0) then
    !               write(204,fmt2) Ids(i), Ids(j), Hii
    !             end if
    !             Hrow(k) = Hii
    !           end do
    !           if (HFullMat) then
    !             write(202,fmt1) Ids(i),Hrow(:)
    !           end if
    !         end do

    !         if (HFullMat) then
    !           close(202)
    !         end if
    !         if (HIJA) then
    !           close(204)
    !         end if

    !         print *, "End writing H matrices"

    !       end if

    !       if (MakeInvH) then
    !         print *, "Start inverting scaled G matrix"
    !         call invert(G22, size(G22, 1), .true., 1)

    !         !print *, "Gw inverted"
    !         !write(fmt2, "(i0)") size(G22,1)
    !         !fmt1="(a8,"//trim(adjustl(fmt2))//"f8.4)"
    !         !do i=1,size(G22,1)
    !         ! write(*,fmt1) IdGeno(i), G22(i,:)
    !         !end do

    !         !print *, "A22 inverted"
    !         !do i=1,size(G22,1)
    !         ! write(*,fmt1) IdGeno(i), InvA22(i,:)
    !         !end do

    !         !print *, "InvA(22)"
    !         !do i=1,size(G22,1)
    !         ! j = i+10
    !         ! write(*,fmt1) Ids(j), InvAMat(j,11:25)
    !         !end do

    !         print *, "End inverting scaled G matrix"

    !         print *, "Start writing inverted H matrices (full and/or ija)"

    !         if (InvHFullMat) then
    !           write(filout,'("InvHFullMatrix"i0,"-"i0".txt")') t1,t2
    !           write(nChar,*) nAnisH
    !           fmt1="(a20,"//trim(adjustl(nChar))//trim(adjustl(OutputFormat))//")"
    !           open(unit=202,file=trim(filout),status="unknown")
    !         end if

    !         if (InvHIJA) then
    !           write(filout,'("InvHija"i0,"-"i0".txt")') t1,t2
    !           fmt2="(a,' ',a,' ',"//trim(adjustl(OutputFormat))//")"
    !           open(unit=204,file=trim(filout),status="unknown")
    !         end if

    !         do i=1,nAnisH
    !           if (AnimToWrite(i) .eq. .false.) then
    !             cycle
    !           end if
    !           Hrow = 0
    !           k = 0
    !           do j=1,nAnisH
    !             if (AnimToWrite(j) .eq. .false.) then
    !               cycle
    !             end if
    !             k = k + 1
    !             if (MapToG(i) .and. MapToG(j)) then
    !               Hrow(k) = G22(MapAnimal(i),MapAnimal(j))
    !               if (i <= nAnisP .and. j <= nAnisP) then
    !                 Hrow(k) = Hrow(k) + InvAMat(i,j) - InvA22(MapToA22(i),MapToA22(j))
    !               end if
    !             else if (i <= nAnisP .and. j <= nAnisP) then !if (MapToG(i) .eq. .false. .and. MapToG(j) .eq. .false.  ) then
    !               Hrow(k) = InvAMat(i,j)
    !             end if
    !             if (InvHIJA .and. i .le. j .and. Hrow(k) /= 0.0d0) then
    !               write(204,fmt2) trim(Ids(i)), trim(Ids(j)), Hrow(k)
    !             end if
    !           end do
    !           if (InvHFullMat) then
    !             write(202,fmt1) Ids(i),Hrow(:)
    !           end if
    !         end do

    !         if (InvHFullMat) then
    !           close(202)
    !         end if
    !         if (InvHIJA) then
    !           close(204)
    !         end if
    !         print *, "End writing inverted H matrices (full and ija)"

    !       end if

    !       deallocate(Hrow)
    !       deallocate(G22)
    !     end do
    !   end do
    !   deallocate(Ids)
    ! end subroutine

    !###########################################################################

    ! subroutine invert(x,n,sym, method)

    !   ! Interface to call inverse subroutines from BLAS/LAPACK libraries

    !   ! x symmetric positive-definite matrix to be inverted
    !   ! n matrix dimension
    !   ! sym return lower-triangular (sym=.false) or full matrix (sym=.true.)
    !   ! method for inversion
    !   ! 0 -- Generalised solving using LU decomposition (dgetrs)
    !   ! 1 -- Cholesky decomposition

    !   implicit none
    !   integer(int32), intent(in) :: n,method
    !   integer(int32) :: i,j,info

    !   real(real64),intent(inout) :: x(n,n)
    !   real(real64),allocatable :: Iden(:,:)

    !   logical, intent(in) :: sym

    !   if (method == 0) then
    !     !Solves a general system of linear equations AX=B, A**T X=B or A**H X=B, using the LU factorization computed by SGETRF/CGETRF
    !     !http://physics.oregonstate.edu/~rubin/nacphy/lapack/routines/dgetrs.html

    !     allocate(Iden(n,n))
    !     ForAll(i = 1:n, j = 1:n) Iden(i,j) = (i/j)*(j/i)  !https://rosettacode.org/wiki/Identity_matrix#Notorious_trick

    !     !https://software.intel.com/en-us/node/468712
    !     !Solves a system of linear equations with an LU-factored square coefficient matrix, with multiple right-hand sides.
    !     ! dgetrs(trans,n,nrhs,A,b,lda,ldb,info)
    !     !Output: Solution overwrites `b`.
    !     call dgetrs("N",n,n,x,Iden,n,n,info)
    !     if (info /= 0) then
    !       print *, "Matrix not positive-definite - info",info
    !       stop 1
    !     end if

    !     x(:,:) = Iden(:,:)

    !   else if (method == 1) then

    !     ! Computes the Cholesky factorization of a symmetric positive definite matrix
    !     ! https://software.intel.com/en-us/node/468690
    !     call dpotrf("L",n,x,n,info)
    !     if (info /= 0) then
    !       print*,"Matrix not positive-definite - info",info
    !       stop 1
    !     end if

    !     ! Computes the inverse of a symmetric positive definite matrix,
    !     !   using the Cholesky factorization computed by dpotrf()
    !     ! https://software.intel.com/en-us/node/468824
    !     call dpotri("L",n,x,n,info)
    !     if (info /= 0) then
    !      print*,"Matrix not positive-definite - info",info
    !      stop 1
    !     end if

    !     ! Fills the upper triangle
    !     if (sym) then
    !       forall (i=1:n,j=1:n,j>i) x(i,j)=x(j,i)
    !     end if

    !   end if
    ! end subroutine

    !###########################################################################

    subroutine AlphaRelateTitle
      implicit none
      write(STDOUT, "(a)") ""
      write(STDOUT, "(a)") "                            ***********************                           "
      write(STDOUT, "(a)") "                            *                     *                           "
      write(STDOUT, "(a)") "                            *     AlphaRelate     *                           "
      write(STDOUT, "(a)") "                            *                     *                           "
      write(STDOUT, "(a)") "                            ***********************                           "
      write(STDOUT, "(a)") "                                                                              "
      write(STDOUT, "(a)") "           Software for calculating relationships among individuals           "
      write(STDOUT, "(a)") "                       http://AlphaGenes.Roslin.ed.ac.uk                      "
      write(STDOUT, "(a)") "                                 No liability                                 "
      write(STDOUT, "(a)") ""
      write(STDOUT, "(a)") "                       Commit:   "//TOSTRING(COMMIT),"                        "
      write(STDOUT, "(a)") "                       Compiled: "//__DATE__//", "//__TIME__
      write(STDOUT, "(a)") ""
    end subroutine

    !###########################################################################

end module

!###############################################################################
