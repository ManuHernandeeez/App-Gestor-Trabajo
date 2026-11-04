using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GestorTrabajoApi.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]
public class AuthController : ControllerBase
{
    private readonly UsuarioRepositorio _usuarios;
    private readonly HashServicio _hash;
    private readonly JwtServicio _jwt;

    public AuthController(UsuarioRepositorio usuarios, HashServicio hash, JwtServicio jwt)
    {
        _usuarios = usuarios;
        _hash = hash;
        _jwt = jwt;
    }

    [HttpPost("registro")]
    public async Task<ActionResult<RegistroRespuesta>> Registro(RegistroSolicitud solicitud)
    {
        var usuarioId = await _usuarios.RegistrarAsync(solicitud, _hash.Hash(solicitud.Password!));
        return StatusCode(StatusCodes.Status201Created, new RegistroRespuesta(usuarioId));
    }

    [HttpPost("login")]
    public async Task<ActionResult<LoginRespuesta>> Login(LoginSolicitud solicitud)
    {
        var usuario = await _usuarios.BuscarPorCorreoAsync(solicitud.Correo ?? "");
        var passwordCorrecta = _hash.Verificar(solicitud.Password ?? "", usuario?.PasswordHash);
        if (usuario == null || !passwordCorrecta)
        {
            return Unauthorized(new ErrorRespuesta("NO_AUTENTICADO", "Correo o contraseña incorrectos"));
        }
        if (usuario.Estado != "activo")
        {
            return StatusCode(StatusCodes.Status403Forbidden,
                new ErrorRespuesta("GT003", "Tu cuenta está suspendida. Contacta al administrador"));
        }

        var token = _jwt.CrearToken(usuario.Id, usuario.Rol, usuario.Nombre);
        return new LoginRespuesta(token, usuario.Rol, usuario.Id, usuario.Nombre);
    }
}
