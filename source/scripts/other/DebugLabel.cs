using Godot;

public partial class DebugLabel : Label
{
    [ExportGroup("Settings")]
    [Export] public float UpdateInterval = 0.25f;

    private bool _isVisible = false;
    private float _updateTimer = 0.0f;

    private float _fps;
    private float _averageFps;
    private float _frameTimeMs;

    private int _accumulatedFrames = 0;
    private float _accumulatedTime = 0.0f;

    public override void _Ready()
    {
        Visible = false;
        ProcessMode = ProcessModeEnum.Always;
    }

    public override void _Input(InputEvent @event)
    {
        if (@event.IsActionPressed("debug"))
        {
            _isVisible = !_isVisible;
            Visible = _isVisible;
        }
    }

    public override void _Process(double delta)
    {
        if (!_isVisible)
        {
            return;
        }

        float unscaledDelta = (float)delta;
        
        if (unscaledDelta > 0.0f)
        {
            _fps = 1.0f / unscaledDelta;
            _frameTimeMs = unscaledDelta * 1000.0f;
        }

        _accumulatedFrames++;
        _accumulatedTime += unscaledDelta;
        _updateTimer += unscaledDelta;

        if (_updateTimer >= UpdateInterval)
        {
            if (_accumulatedTime > 0.0f)
            {
                _averageFps = _accumulatedFrames / _accumulatedTime;
            }

            UpdateText();

            _updateTimer = 0.0f;
            _accumulatedFrames = 0;
            _accumulatedTime = 0.0f;
        }
    }

    private void UpdateText()
    {
        float ramUsage = (float)(Performance.GetMonitor(Performance.Monitor.MemoryStatic) / (1024.0 * 1024.0));
        float objectCount = (float)Performance.GetMonitor(Performance.Monitor.ObjectCount);
        float nodeCount = (float)Performance.GetMonitor(Performance.Monitor.ObjectNodeCount);
        float physicsTime = (float)(Performance.GetMonitor(Performance.Monitor.TimePhysicsProcess) * 1000.0);

        string stats = $"FPS: {Mathf.RoundToInt(_fps)} (Avg: {Mathf.RoundToInt(_averageFps)})\n" +
                       $"Frame Time: {_frameTimeMs:F2} ms\n" +
                       $"Physics Time: {physicsTime:F2} ms\n" +
                       $"Objects: {Mathf.RoundToInt(objectCount)}\n" +
                       $"Nodes: {Mathf.RoundToInt(nodeCount)}\n" +
                       $"RAM (Static): {ramUsage:F2} MB\n" +
                       $"VRAM: {Performance.GetMonitor(Performance.Monitor.RenderVideoMemUsed) / (1024.0f * 1024.0f):F2} MB";

        Text = stats;
    }
}