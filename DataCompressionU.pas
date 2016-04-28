{*
  ������ ��������� ������, ���������� �������� SwingDoor

  ����� TCompressManager �������� ������ ��������� ������ � ��������������
  ��������� ������
  ����� TCompressManager.ReceivePoint() ������������ �������� �������� �����
  � ����������, ����� �� ��������� ����� � ��
}
unit DataCompressionU;

interface

type

  {*
    ����� �� ������������ ��������� XY
  }
  TCompressDataPoint = record
    X: Double;
    Y: Double;
    Status: Integer;

    procedure Init(const AX, AY: Double; const AStatus: Integer);
  end;

  {*
    ��������� ��������� ������������� ������� ������ ��������
  }
  TSlopesRelation = (srNone,
    srNewSUIsIsGreater, // ������ ������� ����� ����������
    srNewSLIsLess,      // ������ ������� ����� ����������
    srSUIsGreaterSL     // ����� ���������
    );

  {*
    ��������� ��������� ����������� �����
  }
  TRecivePointResult = (
    rpNone,
    rpRetainCorridorStartPoint // ���������� ��������� ����� ������ ��������
    );

  {*
    ����� ��������� ������ ������� �����, ������� ���������� ��������� � ��
  }
  TCompressManager = class(TObject)
  private
    FIsNeedInit: Boolean;
    FErrorOffset: Double; // �����������
    FCorridorTimeSec: Int64; // ������������ ����� � ���, � ������� �������� ������ ���� ��������� ������ ���� �����
    FLastRetainDate:  TDateTime;  // ��������� ����� ��������� ������ ������
    FCurrentPoint: TCompressDataPoint; // ������� ����� c �������
    FPreviewPoint: TCompressDataPoint; // ���������� ����� c �������
    FCorridorStartPoint: TCompressDataPoint; // ������� ����� ������ ��������
    FU, FL: TCompressDataPoint; // ������� �����
    FSU, FSL: Double; // ������� ������������ ������� ������ ��������

    procedure EstablishPivotPoints;
    procedure InitSlopes;
    function CalculateCurrentSlopes: TSlopesRelation;
    function IsCorridorTimeExpired: Boolean;
  public
    constructor Create(const AErrorOffset: Double; const ACorridorTimeSec: Int64);

    function ReceivePoint(var ATimeStamp: TDateTime;
      var AValue: Double; var AStatus: Integer): Boolean;

    property CorridorStartPoint: TCompressDataPoint read FCorridorStartPoint;
    property CurrentPoint: TCompressDataPoint read FCurrentPoint;
    property PreviewPoint: TCompressDataPoint read FPreviewPoint;
    property SU: Double read FSU;
    property SL: Double read FSL;
    property PivotU: TCompressDataPoint read FU;
    property PivotL: TCompressDataPoint read FL; 
  end;

implementation

uses
  DateUtils, SysUtils;

{ TCompressManager }

{*
  ������ ������� ������������� ��������
}
function TCompressManager.CalculateCurrentSlopes: TSlopesRelation;
Var
  SU, SL: Double;
begin
  Result := srNone;
  SU := (FCurrentPoint.Y - FCorridorStartPoint.Y - FErrorOffset) /
    (FCurrentPoint.X - FCorridorStartPoint.X);

  SL := (FCurrentPoint.Y - FCorridorStartPoint.Y + FErrorOffset) /
    (FCurrentPoint.X - FCorridorStartPoint.X);

  if (SU > FSU) then
  begin
    FSU := SU;
    Result := srNewSUIsIsGreater;
  end;

  if (SL < FSL) then
  begin
    FSL := SL;
    Result := srNewSLIsLess;
  end;

  if (FSU > FSL) then
  begin
    Result := srSUIsGreaterSL;
  end;
end;

constructor TCompressManager.Create(const AErrorOffset: Double; const ACorridorTimeSec: Int64);
begin
  inherited Create;

  FIsNeedInit := True;
  FErrorOffset := AErrorOffset;
  FCorridorTimeSec := ACorridorTimeSec;
  FLastRetainDate := Now; 
  FSU := 0;
  FSL := 0;
end;

{*
  ������ ������� �����
}
procedure TCompressManager.EstablishPivotPoints;
begin
  FU.Init(FCorridorStartPoint.X, FCorridorStartPoint.Y + FErrorOffset, 0);
  FL.Init(FCorridorStartPoint.X, FCorridorStartPoint.Y - FErrorOffset, 0);
end;

{*
  ������������� ������� ������������� ������ ��������
}
procedure TCompressManager.InitSlopes;
begin
  FSU := (FCurrentPoint.Y - FCorridorStartPoint.Y - FErrorOffset) /
    (FCurrentPoint.X - FCorridorStartPoint.X);

  FSL := (FCurrentPoint.Y - FCorridorStartPoint.Y + FErrorOffset) /
    (FCurrentPoint.X - FCorridorStartPoint.X);
end;

{*
  ���������� True ���� ����� ��������� ������ ����������� FCorridorTimeSec
}
function TCompressManager.IsCorridorTimeExpired: Boolean;
begin
  Result := (SecondsBetween(Now, FLastRetainDate) > FCorridorTimeSec);

  // ���� ����� �������, �� ��������� ��������� ��������� ����� ����������
  if Result then
  begin
    FLastRetainDate := Now;
  end;
end;

{*
  ����������� ����� �����
}
function TCompressManager.ReceivePoint(var ATimeStamp: TDateTime;
  var AValue: Double; var AStatus: Integer): Boolean;
begin
  Result := False;

  FPreviewPoint := FCurrentPoint;
  FCurrentPoint.Init(ATimeStamp, AValue, AStatus);

  // ������ ����� ������������ ��� ���������� �����
  // ����������� ������� �����
  if FIsNeedInit then
  begin
    FCorridorStartPoint := FCurrentPoint;
    EstablishPivotPoints;
    FIsNeedInit := False;

    // ������� ����� ������ ���� ��������� � ��
    FLastRetainDate := Now;
    Result := True;
  end
  else
  begin
    if (FPreviewPoint.X <> FCorridorStartPoint.X) and
      (FPreviewPoint.Y <> FCorridorStartPoint.Y)
    then
    begin

      // �������� ������������ ������� ������ ��������
      case CalculateCurrentSlopes of
        // ���������� ����� ������ � �������
        srNone:
          begin
            // ����� ������ � ������� �������
            // ��������� �� ���� ������ ���� ����� �� ���������
            Result := IsCorridorTimeExpired;
          end;

        // ������� ������� �������� ����������
        srNewSUIsIsGreater:
          begin
            // ��������� ���� ����� ������ ���� ����� �� ���������
            Result := IsCorridorTimeExpired;
          end;

        // ������ ������� �������� ����������
        srNewSLIsLess:
          begin
            // ��������� ���� ����� ������ ���� ����� �� ���������
            Result := IsCorridorTimeExpired;
          end;

        // ����� ���������
        srSUIsGreaterSL:
          begin
            // ������� ����� �� ������ � �������
            // ���������� ����� ��������� ������� ���������� ���������� �������������
            FCorridorStartPoint := FPreviewPoint;
            EstablishPivotPoints;
            InitSlopes;
            FLastRetainDate := Now;

            // ��������� ������ ���������� ����� ��� ����������
            ATimeStamp := FCorridorStartPoint.X;
            AValue := FCorridorStartPoint.Y;
            AStatus := FCorridorStartPoint.Status;

            Result := True;
          end;
      end; //case
    end
    else
    begin
      InitSlopes;
    end;
  end;
end;

{ TDataPoint }

procedure TCompressDataPoint.Init(const AX, AY: Double; const AStatus: Integer);
begin
  X := AX;
  Y := AY;
  Status := AStatus;
end;

end.
