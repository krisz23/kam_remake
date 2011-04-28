unit KM_ServerOverbyte;
{$I KaM_Remake.inc}
interface
uses Classes, SysUtils, WSocket, WSocketS, WinSock;


{ This unit knows nothing about KaM, it's just a puppet in hands of KM_ServerControl,
doing all the low level work on TCP. So we can replace this unit with other TCP client
without KaM even noticing. }
type
  THandleEvent = procedure (aHandle:integer) of object;
  TNotifyDataEvent = procedure(aHandle:integer; aData:pointer; aLength:cardinal)of object;

  TKMServer = class
  private
    fSocketServer:TWSocketServer;
    fLastTag:integer;
    fOnError:TGetStrProc;
    fOnClientConnect:THandleEvent;
    fOnClientDisconnect:THandleEvent;
    fOnDataAvailable:TNotifyDataEvent;
    procedure ClientConnect(Sender: TObject; Client: TWSocketClient; Error: Word);
    procedure ClientDisconnect(Sender: TObject; Client: TWSocketClient; Error: Word);
    procedure DataAvailable(Sender: TObject; Error: Word);
  public
    constructor Create;
    destructor Destroy; override;
    procedure StartListening(aPort:string);
    procedure StopListening;
    procedure SendData(aHandle:integer; aData:pointer; aLength:cardinal);
    property OnError:TGetStrProc write fOnError;
    property OnClientConnect:THandleEvent write fOnClientConnect;
    property OnClientDisconnect:THandleEvent write fOnClientDisconnect;
    property OnDataAvailable:TNotifyDataEvent write fOnDataAvailable;
  end;


implementation


constructor TKMServer.Create;
var wsaData: TWSAData;
begin
  Inherited Create;
  fLastTag := 0;
  if WSAStartup($101, wsaData) <> 0 then
    fOnError('Error in Network');
end;


destructor TKMServer.Destroy;
begin
  if fSocketServer<> nil then fSocketServer.Free;
  Inherited;
end;


procedure TKMServer.StartListening(aPort:string);
begin
  fSocketServer := TWSocketServer.Create(nil);
  fSocketServer.Proto  := 'tcp';
  fSocketServer.Addr   := '0.0.0.0'; //Listen to whole range
  fSocketServer.Port   := aPort;
  fSocketServer.Banner := '';
  fSocketServer.OnClientConnect := ClientConnect;
  fSocketServer.OnClientDisconnect := ClientDisconnect;
  fSocketServer.OnDataAvailable := DataAvailable;
  fSocketServer.Listen;
end;


procedure TKMServer.StopListening;
begin
  if fSocketServer <> nil then fSocketServer.Close;
  FreeAndNil(fSocketServer);
end;


//Someone has connected to us
procedure TKMServer.ClientConnect(Sender: TObject; Client: TWSocketClient; Error: Word);
begin
  if Error <> 0 then
  begin
    fOnError('ClientConnect. Error #' + IntToStr(Error));
    exit;
  end;

  //Identify index of the Client, so we could address it
  inc(fLastTag);
  Client.Tag := fLastTag;

  Client.OnDataAvailable := DataAvailable;
  fOnClientConnect(Client.Tag);
end;


procedure TKMServer.ClientDisconnect(Sender: TObject; Client: TWSocketClient; Error: Word);
begin
  if Error <> 0 then
  begin
    fOnError('ClientConnect. Error #' + IntToStr(Error));
    exit;
  end;

  fOnClientDisconnect(Client.Tag);
end;


//We recieved data from someone
procedure TKMServer.DataAvailable(Sender: TObject; Error: Word);
const BufferSize = 10240; //10kb
var P:pointer; L:cardinal;
begin
  if Error <> 0 then
  begin
    fOnError('ClientConnect. Error #' + IntToStr(Error));
    exit;
  end;

  GetMem(P, BufferSize);
  L := TWSocket(Sender).Receive(P, BufferSize);
  fOnDataAvailable(TWSocket(Sender).Tag, P, L);
  FreeMem(P);
end;


//Make sure we send data to specified client
procedure TKMServer.SendData(aHandle:integer; aData:pointer; aLength:cardinal);
var i:integer;
begin
  for i:=0 to fSocketServer.ClientCount-1 do
    if fSocketServer.Client[i].Tag = aHandle then
      fSocketServer.Client[i].Send(aData, aLength);
end;


end.
