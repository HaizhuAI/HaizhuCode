package io.github.haizhu.code

import java.io.File
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.Path
import java.nio.file.Paths

/**
 * Seeds the HaizhuCode payload into a profile's agent home.
 *
 * The `haizhu` setup component installs the canonical tree at
 * `/opt/haizhu` (kernel, skills, agent roles, MCP registry, prompt library)
 * and seeds every home that exists at install time. A profile created later
 * still needs the kernel and skills before its first agent launch, so
 * [seed] runs from `prepareAgentProfileHome` on every launch: cheap, and it
 * heals a payload installed after the profile.
 *
 * Wiring per home (all inside the Ubuntu rootfs, written from the Android
 * side — the links carry absolute in-proot targets):
 *
 * - `AGENTS.md`, `CLAUDE.md` → kernel (Codex/agents.md convention, Claude user memory)
 * - `.agents/skills` → `/opt/haizhu/skills` (generic skills dir)
 * - `claude/CLAUDE.md`, `claude/skills`, `claude/agents` → payload
 *   (CLAUDE_CONFIG_DIR = <home>/claude: user memory + skills + subagents)
 * - `claude/.claude.json` → MCP servers, written only when absent
 * - `codex/AGENTS.md` → kernel; `codex/config.toml` → kernel as
 *   model_instructions_file + mcp_servers, written only when absent
 * - `.gemini/GEMINI.md`, `.qwen/QWEN.md` → kernel
 * - `.config/opencode/{AGENTS.md,agent,skill,opencode.json}` → payload
 *
 * Nothing is overwritten: links are only created where the path is missing or
 * already one of our links; foreign real files and directories stay as they
 * are. JSON/TOML configs are written once and then owned by the agent/user.
 */
internal object PhoneAgentHaizhu {
    private const val ROOT = "/opt/haizhu"
    private const val KERNEL = "$ROOT/kernel/universal-kernel-v31.md"
    private const val SKILLS = "$ROOT/skills"
    private const val AGENTS = "$ROOT/agents"
    private const val OC_AGENTS_MD = "$ROOT/opencode/AGENTS.md"
    private const val OC_TEMPLATE = "$ROOT/opencode/opencode.json"

    /** The payload marker's Android-side location inside the rootfs. */
    private fun payloadReady(rootfs: File): Boolean =
        File(rootfs, "opt/haizhu/VERSION").isFile

    private fun isOursOrMissing(link: Path): Boolean {
        if (Files.isSymbolicLink(link)) {
            val target = runCatching { Files.readSymbolicLink(link).toString() }.getOrNull()
            return target != null && target.startsWith(ROOT)
        }
        return !Files.exists(link, LinkOption.NOFOLLOW_LINKS)
    }

    /**
     * What `hz remove` reclaims: `F\t<guest path>` for written files,
     * `L\t<guest path>\t<target>` for links. Same format as hz's
     * .hz-manifest so one manifest drives both seeders.
     */
    private class Manifest(private val home: Path, private val guestHome: String) {
        private val entries = linkedSetOf<String>()

        fun file(rel: String) { entries += "F\t$guestHome/$rel" }
        fun link(rel: String, target: String) { entries += "L\t$guestHome/$rel\t$target" }

        fun write() {
            if (entries.isEmpty()) return
            val manifest = home.resolve(".hz-manifest")
            val existing = runCatching {
                Files.readAllLines(manifest).toSet()
            }.getOrDefault(emptySet())
            val fresh = entries.filter { it !in existing }
            if (fresh.isEmpty()) return
            Files.write(
                manifest,
                fresh.joinToString("\n", postfix = "\n").toByteArray(Charsets.UTF_8),
                java.nio.file.StandardOpenOption.CREATE,
                java.nio.file.StandardOpenOption.APPEND,
            )
        }
    }

    private fun link(home: Path, rel: String, target: String, manifest: Manifest): Boolean {
        val link = home.resolve(rel)
        if (!isOursOrMissing(link)) return false
        Files.createDirectories(link.parent)
        Files.deleteIfExists(link)
        Files.createSymbolicLink(link, Paths.get(target))
        manifest.link(rel, target)
        return true
    }

    /**
     * Directory wiring, mirroring hz's `hz_dir`: missing → symlink; a real
     * directory → copy missing payload files into it; anything else is left.
     */
    private fun dir(home: Path, rel: String, target: String, srcDir: File, manifest: Manifest): Int {
        val link = home.resolve(rel)
        if (Files.isDirectory(link, LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(link)) {
            var added = 0
            srcDir.walkTopDown().filter { it.isFile }.forEach { f ->
                val relName = srcDir.toPath().relativize(f.toPath()).joinToString("/")
                val dest = link.resolve(relName)
                if (!Files.exists(dest, LinkOption.NOFOLLOW_LINKS)) {
                    Files.createDirectories(dest.parent)
                    Files.copy(f.toPath(), dest)
                    dest.toFile().setReadable(true, false)
                    manifest.file("$rel/$relName")
                    added++
                }
            }
            return added
        }
        return if (link(home, rel, target, manifest)) 1 else 0
    }

    private fun writeIfAbsent(home: Path, rel: String, content: String, manifest: Manifest): Boolean {
        val file = home.resolve(rel)
        if (Files.exists(file, LinkOption.NOFOLLOW_LINKS) || Files.isSymbolicLink(file)) return false
        Files.createDirectories(file.parent)
        Files.write(file, content.toByteArray(Charsets.UTF_8))
        file.toFile().setReadable(true, false)
        manifest.file(rel)
        return true
    }

    private fun claudeJson(home: String): String = """
{"mcpServers":{"filesystem":{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-filesystem","$home"],"env":{}},"sequential-thinking":{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-sequential-thinking"],"env":{}}}}
""".trimStart()

    private fun codexToml(home: String): String = """
model_instructions_file = "$KERNEL"

[mcp_servers.sequential-thinking]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-sequential-thinking"]

[mcp_servers.filesystem]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-filesystem", "$home"]
""".trimStart()

    private fun opencodeJson(home: String, rootfs: File): String {
        val template = File(rootfs, "opt/haizhu/opencode/opencode.json")
        val text = runCatching { template.readText(Charsets.UTF_8) }.getOrNull()
            ?: return """
{"${"$"}schema":"https://opencode.ai/config.json","instructions":["$KERNEL"],"mcp":{"servers":{}}}
""".trimStart()
        return text.replace("/root/projects", "$home/projects")
    }

    /**
     * Seeds [profileHome]'s agent config dirs. [rootfs] is the Android-side
     * root of the Ubuntu tree; [guestHome] is the in-proot absolute path of
     * the profile home (used inside written configs).
     */
    fun seed(rootfs: File, profileHome: File, guestHome: String): Int {
        if (!payloadReady(rootfs)) return 0
        val home = profileHome.toPath()
        val skillsSrc = File(rootfs, "opt/haizhu/skills")
        val agentsSrc = File(rootfs, "opt/haizhu/agents")
        val manifest = Manifest(home, guestHome)
        var written = 0
        if (link(home, "AGENTS.md", KERNEL, manifest)) written++
        if (link(home, "CLAUDE.md", KERNEL, manifest)) written++
        written += dir(home, ".agents/skills", SKILLS, skillsSrc, manifest)
        if (link(home, "claude/CLAUDE.md", KERNEL, manifest)) written++
        written += dir(home, "claude/skills", SKILLS, skillsSrc, manifest)
        written += dir(home, "claude/agents", AGENTS, agentsSrc, manifest)
        if (writeIfAbsent(home, "claude/.claude.json", claudeJson(guestHome), manifest)) written++
        if (link(home, "codex/AGENTS.md", KERNEL, manifest)) written++
        if (writeIfAbsent(home, "codex/config.toml", codexToml(guestHome), manifest)) written++
        if (link(home, ".gemini/GEMINI.md", KERNEL, manifest)) written++
        if (link(home, ".qwen/QWEN.md", KERNEL, manifest)) written++
        if (link(home, ".config/opencode/AGENTS.md", OC_AGENTS_MD, manifest)) written++
        written += dir(home, ".config/opencode/agent", AGENTS, agentsSrc, manifest)
        written += dir(home, ".config/opencode/skill", SKILLS, skillsSrc, manifest)
        if (writeIfAbsent(home, ".config/opencode/opencode.json", opencodeJson(guestHome, rootfs), manifest)) written++
        manifest.write()
        return written
    }
}
