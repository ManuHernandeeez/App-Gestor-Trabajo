using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace GestorTrabajoApi.Seguridad;

// Crea los tokens de sesión (24 horas) y define cómo se validan. Claims: sub, rol y nombre.
public class JwtServicio
{
    private const int HorasVigencia = 24;

    private readonly SymmetricSecurityKey _clave;
    private readonly string _emisor;
    private readonly string _audiencia;

    public JwtServicio(IConfiguration configuracion)
    {
        var clave = configuracion["Jwt:Clave"];
        if (string.IsNullOrEmpty(clave) || clave.Length < 32)
        {
            throw new InvalidOperationException(
                "Falta Jwt:Clave o tiene menos de 32 caracteres. Configúrala con dotnet user-secrets (ver appsettings.Example.json).");
        }
        _clave = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave));
        _emisor = configuracion["Jwt:Emisor"] ?? "GestorTrabajoApi";
        _audiencia = configuracion["Jwt:Audiencia"] ?? "GestorTrabajoApp";
    }

    public TokenValidationParameters ParametrosValidacion()
    {
        return new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = _emisor,
            ValidateAudience = true,
            ValidAudience = _audiencia,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = _clave,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
            NameClaimType = "nombre",
            RoleClaimType = "rol"
        };
    }

    public string CrearToken(int usuarioId, string rol, string nombre)
    {
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _emisor,
            Audience = _audiencia,
            Expires = DateTime.UtcNow.AddHours(HorasVigencia),
            SigningCredentials = new SigningCredentials(_clave, SecurityAlgorithms.HmacSha256),
            Claims = new Dictionary<string, object>
            {
                ["sub"] = usuarioId.ToString(),
                ["rol"] = rol,
                ["nombre"] = nombre
            }
        };
        return new JsonWebTokenHandler().CreateToken(descriptor);
    }
}
