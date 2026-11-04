namespace GestorTrabajoApi.Seguridad;

// Contraseñas con BCrypt. Nunca se guarda ni se registra la contraseña en texto plano.
public class HashServicio
{
    private const int Costo = 11;

    // Se compara contra este hash cuando el correo no existe, para que el login tarde igual.
    private readonly string _hashFalso = BCrypt.Net.BCrypt.HashPassword("contrasena-que-nadie-usa", Costo);

    public string Hash(string password)
    {
        return BCrypt.Net.BCrypt.HashPassword(password, Costo);
    }

    public bool Verificar(string password, string? hashGuardado)
    {
        var coincide = BCrypt.Net.BCrypt.Verify(password, hashGuardado ?? _hashFalso);
        return hashGuardado != null && coincide;
    }
}
