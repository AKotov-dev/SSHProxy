unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ExtCtrls, IniPropStorage, Process, DefaultTranslator;

type

  { TMainForm }

  TMainForm = class(TForm)
    AutostartBox: TCheckBox;
    ClearBox: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Shape1: TShape;
    StartBtn: TSpeedButton;
    procedure AutostartBoxChange(Sender: TObject);
    procedure ClearBoxChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
  private

  public

  end;

resourcestring
  SAppRunning = 'The program is already running!';
  SStart = 'Start';
  SStop = 'Stop';

var
  MainForm: TMainForm;

implementation

uses portscan_trd;

{$R *.lfm}

{ TMainForm }

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    //  ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Проверка чекбокса ClearBox (очистка кеш/cookies)
function CheckClear: boolean;
begin
  if FileExists(GetUserDir + '.config/sshproxy/clear') then
    Result := True
  else
    Result := False;
end;

//Проверка чекбокса AutoStart
function CheckAutoStart: boolean;
var
  S: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    '[[ -n $(systemctl --user is-enabled sshproxy | grep "enabled") ]] && echo "yes"'],
    S);

  if Trim(S) = 'yes' then
    Result := True
  else
    Result := False;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  Edit1.Width := MainForm.Width div 2 - 10;
  Edit2.Width := Edit1.Width;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  FPortScanThread: TThread;
begin
  IniPropStorage1.Restore;

  //Запуск потока проверки состояния локального порта
  FPortScanThread := PortScan.Create(False);
  FPortScanThread.Priority := tpNormal;

  AutostartBox.Checked := CheckAutoStart;
  ClearBox.Checked := CheckClear;
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
begin
  if Shape1.Brush.Color = clLime then
    //Останавливаем тоннель
    StartProcess('systemctl --user stop sshproxy.service')
  else
  begin
    if Trim(Edit2.Text) <> '' then
      //С паролем
      StartProcess('echo -e "#!/bin/bash\n\nkillall ssh; sshpass -p "' +
        Trim(Edit2.Text) + '" ssh -o \"StrictHostKeyChecking no\" ' +
        Trim(Edit1.Text) + '@' + Trim(Edit3.Text) + ' -L 8080:localhost:' +
        Trim(Edit4.Text) +
        ' -N" > ~/.config/sshproxy/start-tunnel; chmod +x ~/.config/sshproxy/start-tunnel')
    else
      //Без пароля
      StartProcess('echo -e "#!/bin/bash\n\nkillall ssh; ssh -o "StrictHostKeyChecking no" '
        + Trim(Edit1.Text) + '@' + Trim(Edit3.Text) + ' -L 8080:localhost:' +
        Trim(Edit4.Text) +
        ' -N" > ~/.config/sshproxy/start-tunnel; chmod +x ~/.config/sshproxy/start-tunnel');

    //Перезапускаем тоннель
    StartProcess('systemctl --user restart sshproxy.service');
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainForm.Caption := Application.Title;

  //Создаём каталоги настроек
  if not DirectoryExists(GetUserDir + '.config') then MkDir(GetUserDir + '.config');
  if not DirectoryExists(GetUserDir + '.config/sshproxy') then
    MkDir(GetUserDir + '.config/sshproxy');

  IniPropStorage1.IniFileName := GetUserDir + '.config/sshproxy/sshproxy.ini';
end;

procedure TMainForm.ClearBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  if not ClearBox.Checked then
    RunCommand('/bin/bash', ['-c', 'rm -f ~/.config/sshproxy/clear'], S)
  else
    RunCommand('/bin/bash', ['-c', 'touch ~/.config/sshproxy/clear'], S);
end;

procedure TMainForm.AutostartBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;

  if not AutoStartBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl --user disable sshproxy.service'], S)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl --user enable sshproxy.service'], S);
  Screen.Cursor := crDefault;
end;

end.
