{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  HashBase

    Set of base classes for hashing. Sligtly specialized classes for stream
    hashes, block hashes and buffered hashes are provided.

    Stream and block hashes are self explanatory, buffered hashes are those
    that can operate only on an entire message and cannot process streamed
    data and produce intermediary results. For those, the streamed data are
    stored in a memory buffer and then the processing is run as a whole at
    finalization.

  Version 0.4 dev (2020-07-18)

  Last change 2020-08-02

  ©2020 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.HashBase

  Dependencies:
    AuxTypes           - github.com/TheLazyTomcat/Lib.AuxTypes
    AuxClasses         - github.com/TheLazyTomcat/Lib.AuxClasses
    StrRect            - github.com/TheLazyTomcat/Lib.StrRect
    StaticMemoryStream - github.com/TheLazyTomcat/Lib.StaticMemoryStream

===============================================================================}
unit HashBase;

{$IFDEF FPC}
  {$MODE ObjFPC}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}
{$H+}

interface

uses
  SysUtils, Classes,
  AuxTypes, AuxClasses;

{===============================================================================
--------------------------------------------------------------------------------
                                   THashBase
--------------------------------------------------------------------------------
===============================================================================}

type
  THashEndianness = (heDefault,heSystem,heLittle,heBig);  // used in streaming

  THashImplementation = (hiPascal,hiAssembly,hiAccelerated);

  EHASHException = class(Exception);

  EHASHNoStream     = class(EHASHException);
  EHASHInvalidState = class(EHASHException);

{===============================================================================
    THashBase - class declaration
===============================================================================}
type
  THashBase = class(TCustomObject)
  protected
    fReadBufferSize:      TMemSize;   // used as a size of read buffer when processing a stream
    fBufferProgress:      Boolean;
    fProcessedBytes:      TMemSize;
    fBreakProcessing:     Boolean;
    fInitialized:         Boolean;
    fFinalized:           Boolean;
    fOnProgressEvent:     TFloatEvent;
    fOnProgressCallback:  TFloatCallback;
    Function GetHashImplementation: THashImplementation; virtual;
    procedure SetHashImplementation(Value: THashImplementation); virtual;
    procedure DoProgress(Value: Double); virtual;
  {
    ProcessBuffer is a main mean of processing the data and must be implemented
    in all hash-specialized classes.

    It must be able to accept buffer of any size (including the size of 0)
    and must be able to be called multiple times on consecutive data.
  }
    procedure ProcessBuffer(const Buffer; Size: TMemSize); virtual; abstract;
  {
    One-time initialization, called from constructor.
  }
    procedure Initialize; virtual;
  {
    One-time finaliyation, called from destructor.
  }
    procedure Finalize; virtual;
  public
    class Function HashSize: TMemSize; virtual; abstract; // in bytes
    class Function HashName: String; virtual; abstract;
  {
    If we consider the hash to be one large quantity (number), then
    HashEndianness indicates order of bytes in the binary form of the hash.

    The method can only return heLittle or heBig.

    heBig means most significant byte first (lowest memory address), least
    significatn byte last (highest memory address).
    heLittle means least significant byte first, most significant byte last.

    Note that this order is invariant and does not depend on the system
    endianness. To get different endianness, if supported by the hash (in most
    cases only on single-quantity checksums), the descendants should implement
    class methods that will provide a conversion mechanism.
  }
    class Function HashEndianness: THashEndianness; virtual; abstract;
  {
    Returns true when the hash must be finalized (call to method Final) before
    it can be seen as valid and complete.
    When false, the hash can be seen as complete and valid at any point of
    hashing process.
  }
    class Function HashFinalization: Boolean; virtual; abstract;
    // constructors, destructors
    constructor Create;
    constructor CreateAndInit{$IFNDEF FPC}(Dummy: Integer = 0){$ENDIF}; virtual;
  {
    CreateAndInitFrom accepting hash instance can be used to continue hashing,
    unless noted otherwise in hash implementation.

    Other methods from this group cannot be reliably used for that purpose
    (passing a hash might not be enough).
  }
    constructor CreateAndInitFrom(Hash: THashBase); overload; virtual;
    constructor CreateAndInitFromString(const Str: String); virtual;
    destructor Destroy; override;
    // streaming methods
  {
    Init will completely reset internal state and prepares the object for a new
    hashing process.

    Sets Initialized to true and Finalized to false.
  }
    procedure Init; virtual;
  {
    Property Initialized must be set to true and Finalized to false, otherwise
    the Update method will raise an EHASHInvalidState exception.
  }
    procedure Update(const Buffer; Size: TMemSize); virtual;
  {
    Property Initialized must be true and Finalized false, otherwise it raises
    an EHASHInvalidState exception.

    Sets Finalized to true.
  }
    procedure Final(const Buffer; Size: TMemSize); overload; virtual;
    procedure Final; overload; virtual;
    // macro methods
    procedure HashBuffer(const Buffer; Size: TMemSize); virtual;
    procedure HashMemory(Memory: Pointer; Size: TMemSize); virtual;
    procedure HashStream(Stream: TStream; Count: Int64 = -1); virtual;
    procedure HashFile(const FileName: String); virtual;
    procedure HashString(const Str: String); virtual;
    procedure HashAnsiString(const Str: AnsiString); virtual;
    procedure HashWideString(const Str: WideString); virtual;
    // utility methods
    Function Compare(Hash: THashBase): Integer; virtual; abstract;
    Function Same(Hash: THashBase): Boolean; virtual;
    Function AsString: String; virtual; abstract;
    procedure FromString(const Str: String); virtual; abstract;
    Function TryFromString(const Str: String): Boolean; virtual;
    procedure FromStringDef(const Str: String; const Default); virtual;
    // IO
    procedure SaveToStream(Stream: TStream; Endianness: THashEndianness = heDefault); virtual; abstract;
    procedure LoadFromStream(Stream: TStream; Endianness: THashEndianness = heDefault); virtual; abstract;
    procedure SaveToBuffer(var Buffer; Endianness: THashEndianness = heDefault); virtual;
    procedure LoadFromBuffer(const Buffer; Endianness: THashEndianness = heDefault); virtual;
    // properties
    property ReadBufferSize: TMemSize read fReadBufferSize write fReadBufferSize;
    property BufferProgress: Boolean read fBufferProgress write fBufferProgress;
    property ProcessedBytes: TMemSize read fProcessedBytes write fProcessedBytes;
  {
    BreakProcessing, when set to true inside of progress event or callback,
    will cause premature termination of hashing right after return from the
    call.
  }
    property BreakProcessing: Boolean read fBreakProcessing write fBreakProcessing;
  {
    If hash is implemented both in assembly and pascal, this property can be
    used to discern which implementation is currently used, and also to set
    which implementation is to be used next.

    Note that when the unit is compiled in PurePascal mode, asm implementation
    cannot be used and pascal implementation is always used instead,
    irrespective of how you set this property.
  }
    property HashImplementation: THashImplementation read GetHashImplementation write SetHashImplementation;
    property Initialized: Boolean read fInitialized;
    property Finalized: Boolean read fFinalized;
  {
    Progress is reported only from macro methods (HashBuffer, HashMemory, ...).

    When BufferProgress is set to false (default), the progress is reported only
    when processing stream or file. When set to true, the progress is reported
    from all macro methods.
    But note that progress is calculated and reported only on the boundary of
    read buffer, of which size is set in ReadBufferSize property. This means
    that, when processing data smaller than this buffer, no actual progress is
    reported, only 0% (0.0) and 100% (1.0).

    Progress value is normalized, meaning it is reported in the range <0,1>.

    Note that buffered hashes do not report progress at all.
  }
    property OnProgressEvent: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressCallback: TFloatCallback read fOnProgressCallback write fOnProgressCallback;
    property OnProgress: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TStreamHash                                                                    
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TStreamHash - class declaration
===============================================================================}
{
  Stream hash does not contain any implementation because everything needed is
  already implemented in the base class (THashBase).

  Following methods must be overriden or reintroduced (marked with *):

      ProcessBuffer

      HashSize
      HashName
      HashEndianness
      HashFinalization

      CreateAndInitFrom(THashBase)

      Compare
      AsString
      FromString
    * FromStringDef

      SaveToStream
      LoadFromStream

  Following function should also be overriden if the hash calculation
  requires it:

      GetHashImplementation
      SetHashImplementation

      Initialize
      Finalize
      
      Init
      Update
      Final
}
type
  TStreamHash = class(THashBase);

{===============================================================================
--------------------------------------------------------------------------------
                                   TBlockHash                                   
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBlockHash - class declaration
===============================================================================}
{
  TBlockHash should serve as a base for hashes that operates on blocks of fixed
  length (eg. MD5, SHA-1, ...).

  The same methods as for TStreamHash must be overriden/reintroduced.

  Method Initialize must set fBlockSize field to a proper value BEFORE calling
  inherited code (it will allocate internal buffers according to this number).

  Method ProcessFirst is called for a first complete block being processed.
  Method ProcessLast is called at the end of processing for the last block
  being processed (note that it will be stored in fTempBlock buffer).

  ProcessBuffer is fully implemented at this point and descendants should not
  need to override it.

  ProcessBlock is called to process blocks that are not first nor last, but
  ProcessFirst and/or ProcessLast can call it.
}
type
  TBlockHash = class(THashBase)
  protected
    fBlockSize:   TMemSize; // must be set in descendants, in method Initialization, before a call to inherited code
    fFirstBlock:  Boolean;  // set to true in Init, set to false in ProcessFirst
    fTransBlock:  Pointer;  // transfered data/incomplete block data
    fTransCount:  TMemSize; // how many bytes in temp block are passed from previous round
    procedure ProcessBlock(const Block); virtual; abstract;
    procedure ProcessFirst(const Block); virtual;
    procedure ProcessLast; virtual; abstract;
    procedure ProcessBuffer(const Buffer; Size: TMemSize); override;
    procedure Initialize; override;
    procedure Finalize; override;
  public
    constructor CreateAndInitFrom(Hash: THashBase); overload; override;
    procedure Init; override;
    procedure Final; overload; override;
    property BlockSize: TMemSize read fBlockSize;
    property FirstBlock: Boolean read fFirstBlock;
    property Finalized: Boolean read fFinalized;
    property TransBlock: Pointer read fTransBlock;
    property TransCount: TMemSize read fTransCount;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TBufferHash
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBufferHash - class declaration
===============================================================================}
type
  TBufferHash = class(THashBase);
  {todo}

implementation

uses
  StrRect, StaticMemoryStream;

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W4055:={$WARN 4055 OFF}} // Conversion between ordinals and pointers is not portable
  {$DEFINE W5024:={$WARN 5024 OFF}} // Parameter "$1" not used
{$ENDIF}

{===============================================================================
--------------------------------------------------------------------------------
                                   THashBase
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    THashBase - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    THashBase - protected methods
-------------------------------------------------------------------------------}

Function THashBase.GetHashImplementation: THashImplementation;
begin
Result := hiPascal;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure THashBase.SetHashImplementation(Value: THashImplementation);
begin
// do nothing;
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

procedure THashBase.DoProgress(Value: Double);
begin
If Value < 0.0 then
  Value := 0.0
else If Value > 1.0 then
  Value := 1.0;
If Assigned(fOnProgressEvent) then
  fOnProgressEvent(Self,Value);
If Assigned(fOnProgressCallback) then
  fOnProgressCallback(Self,Value);
end;

//------------------------------------------------------------------------------

procedure THashBase.Initialize;
begin
fReadBufferSize := 1024 * 1024; // 1MiB
fBufferProgress := False;
fProcessedBytes := 0;
fBreakProcessing := False;
fInitialized := False;
fFinalized := False;
fOnProgressEvent := nil;
fOnProgressCallback := nil;
end;

//------------------------------------------------------------------------------

procedure THashBase.Finalize;
begin
// nothing to do
end;

{-------------------------------------------------------------------------------
    THashBase - public methods
-------------------------------------------------------------------------------}

constructor THashBase.Create;
begin
inherited Create;
Initialize;
end;

//------------------------------------------------------------------------------

constructor THashBase.CreateAndInit{$IFNDEF FPC}(Dummy: Integer = 0){$ENDIF};
begin
Create;
Init;
end;

//------------------------------------------------------------------------------

constructor THashBase.CreateAndInitFrom(Hash: THashBase);
begin
CreateAndInit;
fProcessedBytes := Hash.ProcessedBytes;
fInitialized := Hash.Initialized;
fFinalized := Hash.Finalized;
end;

//------------------------------------------------------------------------------

constructor THashBase.CreateAndInitFromString(const Str: String);
begin
CreateAndInit;
FromString(Str);
end;

//------------------------------------------------------------------------------

destructor THashBase.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

procedure THashBase.Init;
begin
fProcessedBytes := 0;
fInitialized := True;
fFinalized := False;
end;

//------------------------------------------------------------------------------

procedure THashBase.Update(const Buffer; Size: TMemSize);
begin
If fInitialized then
  begin
    If not fFinalized then
      begin
        ProcessBuffer(Buffer,Size);
        Inc(fProcessedBytes,Size);
      end
    else raise EHASHInvalidState.Create('THashBase.Update: Hash already finalized.');
  end
else raise EHASHInvalidState.Create('THashBase.Update: Hash not initialized.');
end;

//------------------------------------------------------------------------------

procedure THashBase.Final(const Buffer; Size: TMemSize);
begin
Update(Buffer,Size);
Final;
end;

//------------------------------------------------------------------------------

procedure THashBase.Final;
begin
If fInitialized then
  begin
    If not fFinalized then
      fFinalized := True
    else
      raise EHASHInvalidState.Create('THashBase.Final: Hash already finalized.');
  end
else raise EHASHInvalidState.Create('THashBase.Final: Hash not initialized.');
end;

//------------------------------------------------------------------------------

procedure THashBase.HashBuffer(const Buffer; Size: TMemSize);
var
  Stream: TStaticMemoryStream;
begin
If fBufferProgress then
  begin
    Stream := TStaticMemoryStream.Create(@Buffer,Size);
    try
      HashStream(Stream);
    finally
      Stream.Free;
    end;
  end
else
  begin
    Init;
    Final(Buffer,Size);
  end;
end;

//------------------------------------------------------------------------------

procedure THashBase.HashMemory(Memory: Pointer; Size: TMemSize);
begin
HashBuffer(Memory^,Size);
end;

//------------------------------------------------------------------------------

procedure THashBase.HashStream(Stream: TStream; Count: Int64 = -1);
var
  Buffer:     Pointer;
  BytesRead:  Integer;
  InitCount:  Int64;

  Function Min(A,B: Int64): Int64;  // so there is no need to link Math unit
  begin
    If A < B then
      Result := A
    else
      Result := B;
  end;

begin
If Assigned(Stream) then
  begin
    Init;  
    If Count = 0 then
      Count := Stream.Size - Stream.Position;
    If Count < 0 then
      begin
        Stream.Seek(0,soBeginning);
        Count := Stream.Size;
      end;
    InitCount := Count;
    DoProgress(0.0);
    If InitCount > 0 then
      begin
        GetMem(Buffer,fReadBufferSize);
        try
          fBreakProcessing := False;
          repeat
            BytesRead := Stream.Read(Buffer^,Min(fReadBufferSize,Count));
            Update(Buffer^,TMemSize(BytesRead));
            Dec(Count,BytesRead);
            DoProgress((InitCount - Count) / InitCount);
          until (TMemSize(BytesRead) < fReadBufferSize) or fBreakProcessing;
        finally
          FreeMem(Buffer,fReadBufferSize);
        end;
      end
    else DoProgress(1.0);
    Final;
  end
else raise EHASHNoStream.Create('THashBase.HashStream: Stream not assigned.');
end;

//------------------------------------------------------------------------------

procedure THashBase.HashFile(const FileName: String);
var
  FileStream: TFileStream;
begin
FileStream := TFileStream.Create(StrToRTL(FileName),fmOpenRead or fmShareDenyWrite);
try
  HashStream(FileStream);
finally
  FileStream.Free;
end;
end;

//------------------------------------------------------------------------------

procedure THashBase.HashString(const Str: String);
begin 
HashMemory(PChar(Str),Length(Str) * SizeOf(Char));
end;

//------------------------------------------------------------------------------

procedure THashBase.HashAnsiString(const Str: AnsiString);
begin 
HashMemory(PAnsiChar(Str),Length(Str) * SizeOf(AnsiChar));
end;

//------------------------------------------------------------------------------

procedure THashBase.HashWideString(const Str: WideString);
begin 
HashMemory(PWideChar(Str),Length(Str) * SizeOf(WideChar));
end;

//------------------------------------------------------------------------------

Function THashBase.Same(Hash: THashBase): Boolean;
begin
Result := Compare(Hash) = 0;
end;

//------------------------------------------------------------------------------

Function THashBase.TryFromString(const Str: String): Boolean;
begin
try
  FromString(Str);
  Result := True;
except
  Result := False;
end;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure THashBase.FromStringDef(const Str: String; const Default);
begin
// no implementation here
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

procedure THashBase.SaveToBuffer(var Buffer; Endianness: THashEndianness = heDefault);
var
  Stream: TWritableStaticMemoryStream;
begin
Stream := TWritableStaticMemoryStream.Create(@Buffer,HashSize);
try
  SaveToStream(Stream,Endianness);
finally
  Stream.Free;
end;
end;

//------------------------------------------------------------------------------

procedure THashBase.LoadFromBuffer(const Buffer; Endianness: THashEndianness = heDefault);
var
  Stream: TStaticMemoryStream;
begin
Stream := TStaticMemoryStream.Create(@Buffer,HashSize);
try
  LoadFromStream(Stream,Endianness);
finally
  Stream.Free;
end;
end;

{===============================================================================
--------------------------------------------------------------------------------
                                   TBlockHash                                   
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBlockHash - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TBlockHash - protected methods
-------------------------------------------------------------------------------}

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TBlockHash.ProcessFirst(const Block);
begin
fFirstBlock := False;
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}  

//------------------------------------------------------------------------------

procedure TBlockHash.ProcessBuffer(const Buffer; Size: TMemSize);
var
  RemainingSize:  TMemSize;
  WorkPtr:        Pointer;
  i:              Integer;  

  procedure DispatchBlock(const Block);
  begin
    If fFirstBlock then
      ProcessFirst(Block)
    else
      ProcessBlock(Block);
  end;

begin
If Size > 0 then
  begin
    If fTransCount > 0 then
      begin
        // some data are stored in the temp block
        If (fTransCount + Size) >= fBlockSize then
          begin
            // data will fill, and potentially overflow, the transfer block
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            Move(Buffer,Pointer(PtrUInt(fTransBlock) + PtrUInt(fTransCount))^,fBlockSize - fTransCount);
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
            DispatchBlock(fTransBlock^);
            RemainingSize := Size - (fBlockSize - fTransCount);
            fTransCount := 0;
            If RemainingSize > 0 then
            {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
              ProcessBuffer(Pointer(PtrUInt(Addr(Buffer)) + PtrUInt(Size - RemainingSize))^,RemainingSize);
            {$IFDEF FPCDWM}{$POP}{$ENDIF}
          end
        else
          begin
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            // data will not fill the transfer block, store end return
            Move(Buffer,Pointer(PtrUInt(fTransBlock) + PtrUInt(fTransCount))^,Size);
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
            Inc(fTransCount,Size);
          end;
      end
    else
      begin
        // nothing is stored in the transfer block
        WorkPtr := Addr(Buffer);
        // process whole blocks
        For i := 1 to Integer(Size div fBlockSize) do
          begin
            DispatchBlock(WorkPtr^);
          {$IFDEF FPCDWM}{$PUSH}W4055{$ENDIF}
            WorkPtr := Pointer(PtrUInt(WorkPtr) + PtrUInt(fBlockSize));
          {$IFDEF FPCDWM}{$POP}{$ENDIF}
          end;
        // store partial block (if any)
        fTransCount := Size mod fBlockSize;
        If fTransCount > 0 then
          Move(WorkPtr^,fTransBlock^,fTransCount);
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.Initialize;
begin
// fBlockSize should be set from descendant at this point
inherited;
fFirstBlock := True;
fTransBlock := AllocMem(fBlockSize); // also inits fBlockSize to all 0
fTransCount := 0;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.Finalize;
begin
FreeMem(fTransBlock,fBlockSize);
inherited;
end;

{-------------------------------------------------------------------------------
    TBlockHash - public methods
-------------------------------------------------------------------------------}

constructor TBlockHash.CreateAndInitFrom(Hash: THashBase);
begin
inherited CreateAndInitFrom(Hash);
If Hash is TBlockHash then
  begin
    fFirstBlock := TBlockHash(Hash).FirstBlock;
    fTransCount := TBlockHash(Hash).TransCount;
    Move(TBlockHash(Hash).TransBlock^,fTransBlock^,fTransCount);
  end;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.Init;
begin
inherited;
fFirstBlock := True;
FillChar(fTransBlock^,fBlockSize,0);
fTransCount := 0;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.Final;
begin
ProcessLast;
inherited;
end;

end.
