using Godot;

public partial class PlayerLook : Node3D
{
    public enum LookMode
    {
        Mouse,
        Action
    }

    [ExportGroup("Look Settings")]
    [Export] public LookMode CurrentLookMode = LookMode.Mouse;
    [Export(PropertyHint.Range, "0.01,10.0")] public float Sensitivity = 2.0f;
    [Export] public float MinPitch = -85.0f;
    [Export] public float MaxPitch = 85.0f;

    [ExportGroup("References")]
    [Export] public Node3D PlayerBody;
    [Export] public Node3D HeadNode;

    private float _pitch = 0.0f;

    public override void _Ready()
    {
        if (CurrentLookMode == LookMode.Mouse)
        {
            Input.MouseMode = Input.MouseModeEnum.Captured;
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (CurrentLookMode == LookMode.Mouse && @event is InputEventMouseMotion mouseMotion)
        {
            Vector2 lookDelta = mouseMotion.Relative * 0.1f;
            ApplyLook(lookDelta);
        }
    }

    public override void _Process(double delta)
    {
        if (CurrentLookMode == LookMode.Action)
        {
            Vector2 lookDelta = Input.GetVector("look_left", "look_right", "look_up", "look_down") * 0.25f;
            ApplyLook(lookDelta);
        }
    }

    private void ApplyLook(Vector2 lookDelta)
    {
        if (lookDelta.X == 0.0f && lookDelta.Y == 0.0f)
        {
            return;
        }

        if (lookDelta.X != 0.0f)
        {
            Vector3 bodyRot = PlayerBody.Rotation;
            bodyRot.Y -= Mathf.DegToRad(lookDelta.X * Sensitivity);
            PlayerBody.Rotation = bodyRot;
        }

        if (lookDelta.Y != 0.0f)
        {
            _pitch -= lookDelta.Y * Sensitivity;

            if (_pitch > MaxPitch)
            {
                _pitch = MaxPitch;
            }
            else if (_pitch < MinPitch)
            {
                _pitch = MinPitch;
            }

            Vector3 camRot = HeadNode.Rotation;
            camRot.X = Mathf.DegToRad(_pitch);
            HeadNode.Rotation = camRot;
        }
    }
}