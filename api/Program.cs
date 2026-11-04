using GestorTrabajoApi.Modelos;
using GestorTrabajoApi.Repositorios;
using GestorTrabajoApi.Seguridad;
using GestorTrabajoApi.Servicios;
using GestorTrabajoApi.Tareas;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.FileProviders;
using Microsoft.OpenApi;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var cadenaConexion = builder.Configuration.GetConnectionString("GestorTrabajo")
    ?? throw new InvalidOperationException(
        "Falta ConnectionStrings:GestorTrabajo. Configúrala con dotnet user-secrets (ver appsettings.Example.json).");
var jwt = new JwtServicio(builder.Configuration);

builder.Services.AddSingleton(NpgsqlDataSource.Create(cadenaConexion));
builder.Services.AddSingleton<BaseDatos>();
builder.Services.AddScoped<UsuarioRepositorio>();
builder.Services.AddScoped<PerfilRepositorio>();
builder.Services.AddScoped<SolicitudRepositorio>();
builder.Services.AddScoped<PropuestaRepositorio>();
builder.Services.AddScoped<CatalogoRepositorio>();
builder.Services.AddScoped<CalificacionRepositorio>();
builder.Services.AddScoped<MensajeRepositorio>();
builder.Services.AddScoped<AvisoRepositorio>();
builder.Services.AddHostedService<VencimientoTarea>();
builder.Services.AddSingleton<HashServicio>();
builder.Services.AddSingleton<FotoServicio>();
builder.Services.AddSingleton(jwt);

builder.Services.AddControllers(mvc =>
{
    mvc.SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true;
}).ConfigureApiBehaviorOptions(opciones =>
{
    // Los mensajes del framework vienen en inglés. Solo se muestran los propios (de los atributos de
    // validación, cuya llave es el nombre del campo); un JSON roto o de tipo equivocado (llave "$...")
    // y un cuerpo vacío (llave "") salen con el texto genérico.
    opciones.InvalidModelStateResponseFactory = contexto =>
    {
        var mensaje = contexto.ModelState
            .Where(campo => campo.Key != "" && !campo.Key.StartsWith('$') && campo.Value != null)
            .SelectMany(campo => campo.Value!.Errors)
            .Where(error => error.Exception == null && !string.IsNullOrWhiteSpace(error.ErrorMessage))
            .Select(error => error.ErrorMessage)
            .FirstOrDefault() ?? "Los datos enviados no son válidos";
        return new BadRequestObjectResult(new ErrorRespuesta("SOLICITUD_INVALIDA", mensaje));
    };
});

builder.Services.AddExceptionHandler<ManejadorErrores>();
builder.Services.AddProblemDetails();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opciones =>
    {
        opciones.MapInboundClaims = false;
        opciones.TokenValidationParameters = jwt.ParametrosValidacion();
        opciones.Events = EventosJwt.Crear();
    });
builder.Services.AddAuthorization();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(opciones =>
{
    opciones.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Token que devuelve POST /api/auth/login"
    });
    opciones.AddSecurityRequirement(documento => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", documento)] = new List<string>()
    });
});

var app = builder.Build();

await AdministradorSemilla.AsegurarAsync(app.Services);

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Las fotos de perfil se sirven como archivos estáticos; los nombres son GUID y no se pueden adivinar
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(app.Services.GetRequiredService<FotoServicio>().Carpeta),
    RequestPath = "/fotos"
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
