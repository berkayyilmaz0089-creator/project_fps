using Godot;

public partial class PlayerAudio : Node
{
    [ExportGroup("Default Audio")]
    [Export] public AudioStream DefaultWalkClip;
    [Export] public AudioStream DefaultJumpClip;
    [Export] public AudioStream DefaultLandClip;

    [ExportGroup("Tagged Audio")]
    [Export] public Godot.Collections.Array<string> TaggedGroups = new Godot.Collections.Array<string>();
    [Export] public Godot.Collections.Array<AudioStream> TaggedWalkClips = new Godot.Collections.Array<AudioStream>();
    [Export] public Godot.Collections.Array<AudioStream> TaggedJumpClips = new Godot.Collections.Array<AudioStream>();
    [Export] public Godot.Collections.Array<AudioStream> TaggedLandClips = new Godot.Collections.Array<AudioStream>();

    [ExportGroup("Audio Settings")]
    [Export] public float MinPitch = 0.85f;
    [Export] public float MaxPitch = 1.15f;
    [Export(PropertyHint.Layers3DPhysics)] public uint GroundMask = 1;

    [ExportGroup("Movement Intervals")]
    [Export] public float WalkInterval = 0.5f;
    [Export] public float SprintInterval = 0.35f;
    [Export] public float CrouchInterval = 0.8f;

    [ExportGroup("References")]
    [Export] public CharacterBody3D PlayerBody;
    [Export] public PlayerMovement PlayerMovement;
    [Export] public AudioStreamPlayer3D AudioSource;
    
    private float _stepTimer = 0.0f;
    private bool _wasOnFloor = true;
    private RandomNumberGenerator _rng = new RandomNumberGenerator();

    public override void _Ready()
    {
        if (PlayerBody == null)
        {
            PlayerBody = GetParent() as CharacterBody3D;
        }

        if (PlayerMovement == null && PlayerBody != null)
        {
            PlayerMovement = PlayerBody.GetNodeOrNull<PlayerMovement>("PlayerMovement");
        }

        if (AudioSource == null)
        {
            AudioSource = GetNodeOrNull<AudioStreamPlayer3D>("AudioStreamPlayer3D");
        }
        
        _rng.Randomize();
    }

    public override void _Process(double delta)
    {
        if (PlayerBody == null)
        {
            return;
        }

        bool isOnFloor = PlayerBody.IsOnFloor();

        if (_wasOnFloor && !isOnFloor)
        {
            if (PlayerBody.Velocity.Y > 0.1f)
            {
                PlayJumpAudio();
            }
        }
        else if (!_wasOnFloor && isOnFloor)
        {
            PlayLandAudio();
        }

        _wasOnFloor = isOnFloor;

        if (!isOnFloor)
        {
            _stepTimer = 0.0f;
            return;
        }

        Vector3 velocity = PlayerBody.Velocity;
        float currentSpeedSqr = velocity.X * velocity.X + velocity.Z * velocity.Z;

        if (currentSpeedSqr < 0.01f)
        {
            _stepTimer = 0.0f;
            return;
        }

        _stepTimer += (float)delta;
        float currentInterval = GetCurrentInterval(Mathf.Sqrt(currentSpeedSqr));

        if (_stepTimer >= currentInterval)
        {
            PlayWalkAudio();
            _stepTimer = 0.0f;
        }
    }

    private float GetCurrentInterval(float currentSpeed)
    {
        if (PlayerMovement != null)
        {
            if (currentSpeed <= PlayerMovement.CrouchSpeed + 0.2f)
            {
                return CrouchInterval;
            }
            
            if (currentSpeed >= PlayerMovement.SprintSpeed - 0.5f)
            {
                return SprintInterval;
            }
        }

        return WalkInterval;
    }

    private (AudioStream walk, AudioStream jump, AudioStream land) GetSurfaceClips()
    {
        var spaceState = PlayerBody.GetWorld3D().DirectSpaceState;
        
        Vector3 origin = PlayerBody.GlobalPosition + Vector3.Up * 0.5f;
        Vector3 end = origin + Vector3.Down * 2.0f;

        var query = PhysicsRayQueryParameters3D.Create(origin, end, GroundMask);
        var result = spaceState.IntersectRay(query);

        if (result.Count > 0)
        {
            var hitCollider = result["collider"].AsGodotObject() as Node;

            if (hitCollider != null)
            {
                int maxCount = Mathf.Min(TaggedGroups.Count, TaggedWalkClips.Count);
                
                for (int i = 0; i < maxCount; i++)
                {
                    if (!string.IsNullOrEmpty(TaggedGroups[i]) && hitCollider.IsInGroup(TaggedGroups[i]))
                    {
                        AudioStream walk = i < TaggedWalkClips.Count ? TaggedWalkClips[i] : null;
                        AudioStream jump = i < TaggedJumpClips.Count ? TaggedJumpClips[i] : null;
                        AudioStream land = i < TaggedLandClips.Count ? TaggedLandClips[i] : null;
                        
                        return (walk, jump, land);
                    }
                }
            }
        }

        return (DefaultWalkClip, DefaultJumpClip, DefaultLandClip);
    }

    private void PlayWalkAudio()
    {
        var clips = GetSurfaceClips();

        if (clips.walk != null)
        {
            PlayClipWithPitch(clips.walk);
        }
    }

    private void PlayJumpAudio()
    {
        var clips = GetSurfaceClips();

        if (clips.jump != null)
        {
            PlayClipWithPitch(clips.jump);
        }
    }

    private void PlayLandAudio()
    {
        var clips = GetSurfaceClips();

        if (clips.land != null)
        {
            PlayClipWithPitch(clips.land);
        }
    }

    private void PlayClipWithPitch(AudioStream clip)
    {
        if (AudioSource == null)
        {
            return;
        }

        AudioSource.PitchScale = _rng.RandfRange(MinPitch, MaxPitch);
        AudioSource.Stream = clip;
        AudioSource.Play();
    }
}