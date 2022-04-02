unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons, ShellApi,
  StdCtrls, LCLType, LazUTF8, Windows;

type
  TMainFrm = class(TForm)
    btnClose: TBitBtn;
    btnExplore: TBitBtn;
    btnDelete: TBitBtn;
    ButtonPanel: TPanel;
    ImageGroupBox: TGroupBox;
    MainImage: TImage;
    Timer: TTimer;
    procedure btnCloseClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnExploreClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TimerTimer(Sender: TObject);
  private
    FCurrentFile: String;
    FSettingsFile: String;
    FMainDir: String;
    FLanguageDir: String;
    FCurrentLanguage: String;

    FLngDialogDelete: String;
    FSkipDeleteDialog: Boolean;

    procedure SaveSettings;
    procedure LoadSettings;
    procedure LoadLanguageFromFile(FileName: String);
    procedure ArrangeItems;
    procedure SetEmptyImage;
    function  GetWallpaperFilePathFromRegistry: String;
    procedure Refresh;

    procedure SetCurrentFile(AValue: String);

    property CurrentFile: String read FCurrentFile write SetCurrentFile;
  public

  end;

var
  MainFrm: TMainFrm;

implementation

uses
  Registry, IniFiles, sgeWindowsVersion;

const
  APP_VERSION = '0.1';
  SECTION_SYSTEM = 'System';
  PARAM_LANGUAGE = 'Language';
  PARAM_SKIP_DELETE_MESSAGE = 'SkipDeleteMessage';

{$R *.lfm}


procedure TMainFrm.FormCreate(Sender: TObject);
begin
  FMainDir := ExtractFilePath(ParamStr(0));
  FLanguageDir := FMainDir + 'Languages\';
  ForceDirectories(FLanguageDir);
  FSettingsFile := FMainDir + 'WallpaperInspector.ini';

  LoadSettings;
  LoadLanguageFromFile(FLanguageDir + FCurrentLanguage);

  CurrentFile := '';
  ArrangeItems;
  Refresh;
end;


procedure TMainFrm.FormDestroy(Sender: TObject);
begin
  SaveSettings;
end;


procedure TMainFrm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE: btnClose.Click;
  end;
end;


procedure TMainFrm.TimerTimer(Sender: TObject);
begin
  Refresh;
end;

procedure TMainFrm.SaveSettings;
var
  F: TIniFile;
begin
  F :=  TIniFile.Create(FSettingsFile);
  F.WriteString(SECTION_SYSTEM, PARAM_LANGUAGE, FCurrentLanguage);
  F.WriteBool(SECTION_SYSTEM, PARAM_SKIP_DELETE_MESSAGE, FSkipDeleteDialog);
  F.Free;
end;


procedure TMainFrm.LoadSettings;
var
  F: TIniFile;
begin
  F :=  TIniFile.Create(FSettingsFile);
  FCurrentLanguage := F.ReadString(SECTION_SYSTEM, PARAM_LANGUAGE, 'English.Lng');
  FSkipDeleteDialog := F.ReadBool(SECTION_SYSTEM, PARAM_SKIP_DELETE_MESSAGE, False);
  F.Free;
end;


procedure TMainFrm.LoadLanguageFromFile(FileName: String);
const
  SectionUI = 'UI';
  SectionDialog = 'Dialogs';
var
  F: TIniFile;
begin
  F := TIniFile.Create(FileName);
  Caption := F.ReadString(SectionUI, 'Caption', 'Wallpaper Inspector') + ' - ' + APP_VERSION;
  ImageGroupBox.Caption := F.ReadString(SectionUI, 'ImageBox', 'Image');
  btnExplore.Caption := F.ReadString(SectionUI, 'ButtonExplore', 'Explore');
  btnDelete.Caption := F.ReadString(SectionUI, 'ButtonDelete', 'Delete');
  btnClose.Caption := F.ReadString(SectionUI, 'ButtonClose', 'Close');

  FLngDialogDelete := F.ReadString(SectionDialog, 'Delete', 'Delete image?');
  F.Free;
end;


procedure TMainFrm.SetCurrentFile(AValue: String);
var
  b: Boolean;
begin
  FCurrentFile := AValue;

  MainImage.Hint := FCurrentFile;

  //Поправить кнопки
  b := FileExists(FCurrentFile);
  btnExplore.Enabled := b;
  btnDelete.Enabled := b;
end;


procedure TMainFrm.ArrangeItems;
begin
  ClientWidth := ImageGroupBox.Width + ImageGroupBox.Left * 2;
  ClientHeight := ImageGroupBox.Top + ImageGroupBox.Height + 5 + ButtonPanel.Height;
  ButtonPanel.Width := ClientWidth;
  btnClose.Left := ButtonPanel.ClientWidth - (btnClose.Width + 5);
end;

procedure TMainFrm.SetEmptyImage;
begin
  MainImage.Picture.LoadFromResourceName(HINSTANCE, 'EMPTYIMAGE');
end;


function TMainFrm.GetWallpaperFilePathFromRegistry: String;
type
  TRegValueType = (rvtString, rvtBinary);

  function ReadRegValue(Reg: TRegistry; Path, Key: String; ValueType: TRegValueType = rvtString): String;
  type
    TBuf = record
      Trash: array[0..23] of Byte;
      FileName: array[0..800] of WideChar;
    end;
  var
    Buf: TBuf;
    Size: Integer;
  begin
    Result := '';
    if Reg.OpenKeyReadOnly(Path) then
    begin
      if Reg.ValueExists(Key) then
      begin
        case ValueType of
          rvtString: Result := Reg.ReadString(Key);
          rvtBinary:
            begin
            Size := Reg.GetDataSize(Key);
            Reg.ReadBinaryData(Key, Buf, Size);
            Result := Buf.FileName;
            end;
        end;
      end;
      Reg.CloseKey;
    end;
  end;

const
  Win7_KeyPath = 'Software\Microsoft\Internet Explorer\Desktop\General';
  Win7_KeyName = 'WallpaperSource';
  Win10_KeyPath = 'Control Panel\Desktop';
  Win10_KeyName = 'TranscodedImageCache';

var
  Reg: TRegistry;
  Ver: TsgeWindowsVersion;
begin
  Ver := sgeGetWindowsVersion;
  Result := '';
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    //Прочитать путь к файлу в зависимости от версии ОС
    case Ver of
      wvUnknown : Exit;
      wv7       : Result := ReadRegValue(Reg, Win7_KeyPath, Win7_KeyName);
      else
        Result := ReadRegValue(Reg, Win10_KeyPath, Win10_KeyName, rvtBinary);
    end;

  finally
    Reg.Free;
  end;
end;


procedure TMainFrm.Refresh;
var
  fn: String;
begin
  //Получить имя файла из реестра
  fn := GetWallpaperFilePathFromRegistry;

  //Если этот файл уже загружен, то выход
  if fn = FCurrentFile then Exit;

  //Проверить существование файла
  if FileExists(fn) then
  begin
    //Запомнить имя файла
    CurrentFile := fn;

    //Загрузить картинку
    try
      MainImage.Picture.LoadFromFile(FCurrentFile);
    except
      SetEmptyImage;
    end;

  end
  else
    SetEmptyImage;
end;


procedure TMainFrm.btnCloseClick(Sender: TObject);
begin
  Close;
end;


procedure TMainFrm.btnDeleteClick(Sender: TObject);
var
  FileOp: TSHFILEOPSTRUCTW;
  ErrCode: Integer;
begin
  if not FSkipDeleteDialog then
    if MessageDlg('', FLngDialogDelete + sLineBreak + FCurrentFile, mtConfirmation, mbYesNo, 0) = mrNo then Exit;

  FileOp.wFunc := FO_DELETE;
  FileOp.wnd := Handle;
  FileOp.pFrom := PWideChar(UTF8ToUTF16(FCurrentFile + #0));
  FileOp.fFlags := FOF_SILENT or FOF_ALLOWUNDO;
  ErrCode := SHFileOperationW(@FileOp);
  if ErrCode = 0 then
  begin
    CurrentFile := '';
    SetEmptyImage;
  end
  else
      ShowMessage('File delete error');
end;


procedure TMainFrm.btnExploreClick(Sender: TObject);
begin
  ShellExecute(Handle, nil, 'explorer', PChar(UTF8ToWinCP('/Select,"' + FCurrentFile + '"')), nil, SW_SHOWNORMAL);
end;


end.

