using Godot;

public partial class BounceScene : Node2D
{
	private Vector2 _velocity = new Vector2(300f, 200f);
	private Sprite2D _sprite;

	public override void _Ready()
	{
		_sprite = GetNode<Sprite2D>("Sprite2D");
		_sprite.Position = GetViewportRect().Size / 2f;
	}

	public override void _Process(double delta)
	{
		var rect = GetViewportRect();
		var halfSize = _sprite.Texture != null
			? _sprite.Texture.GetSize() / 2f
			: Vector2.Zero;

		_sprite.Position += _velocity * (float)delta;

		if (_sprite.Position.X - halfSize.X < 0 || _sprite.Position.X + halfSize.X > rect.Size.X)
			_velocity.X *= -1f;

		if (_sprite.Position.Y - halfSize.Y < 0 || _sprite.Position.Y + halfSize.Y > rect.Size.Y)
			_velocity.Y *= -1f;

		_sprite.Position = _sprite.Position.Clamp(halfSize, rect.Size - halfSize);
	}
}
